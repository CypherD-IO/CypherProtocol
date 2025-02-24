// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Enum} from "lib/safe-contracts/contracts/common/Enum.sol";
import {ModuleManager} from "lib/safe-contracts/contracts/base/ModuleManager.sol";

/// @title Gnosis Safe Emission Module
/// @notice Manages token emissions according to a predefined schedule
/// @dev Implements Gnosis Safe module interface for execution
/// This contract will hold no tokens, it is simply responsible for coordinating
/// emissions being sent out of the Safe to the emission address which will
/// reward Cypher holders according to the schedule.
contract DistributionModule is Ownable {
    /// @notice Structure to store emission schedule data
    struct EmissionSchedule {
        uint256 startTime; // Start time of the schedule
        uint256 tokensPerWeek; // Tokens to emit per week
        uint256 durationWeeks; // Duration in weeks
    }

    /// @notice Address where emissions are sent
    address public emissionAddress;

    /// @notice Token being emitted
    IERC20 public immutable token;

    /// @notice Gnosis Safe that holds the tokens
    address public immutable safe;

    /// @notice Last emission timestamp
    uint256 public lastEmissionTime;

    /// @notice Array of emission schedules
    EmissionSchedule[] public emissionSchedules;

    /// @notice Weekly duration in seconds
    uint256 public constant WEEK = 7 days;

    /// @notice Emitted when tokens are distributed
    event TokensEmitted(uint256 amount, address recipient);

    /// @notice Emitted when emission address is updated
    event EmissionAddressUpdated(address oldAddress, address newAddress);

    /// @param _owner Address of the governor
    /// @param _safe Address of the Gnosis Safe
    /// @param _token Address of the token to emit
    /// @param _emissionAddress Initial emission address
    constructor(address _owner, address _safe, address _token, address _emissionAddress) Ownable(_owner) {
        require(_safe != address(0), "Invalid Safe address");
        require(_token != address(0), "Invalid token address");
        require(_emissionAddress != address(0), "Invalid emission address");

        safe = _safe;
        token = IERC20(_token);
        emissionAddress = _emissionAddress;
        lastEmissionTime = block.timestamp;

        // Initialize emission schedule
        _initializeEmissionSchedule();
    }

    /// @dev Helper to push a new emission schedule
    /// @param totalTokens Number of tokens in millions
    /// @param durationWeeks Duration in weeks
    /// @param startTime Current start time
    /// @return newStartTime Updated start time for next schedule
    function _pushEmissionSchedule(uint256 totalTokens, uint256 durationWeeks, uint256 startTime)
        private
        returns (uint256 newStartTime)
    {
        emissionSchedules.push(
            EmissionSchedule(
                startTime,
                totalTokens * 1_000_000e18, // Weekly rate (totalTokens is in millions)
                durationWeeks
            )
        );
        return startTime + (durationWeeks * WEEK);
    }

    /// @notice Initialize the emission schedule according to the specified timeline
    function _initializeEmissionSchedule() private {
        uint256 startTime = block.timestamp;

        // First 24 months - 13 week periods
        startTime = _pushEmissionSchedule(5, 13, startTime); // 0-3 months - 5M tokens
        startTime = _pushEmissionSchedule(10, 13, startTime); // 3-6 months - 10M tokens
        startTime = _pushEmissionSchedule(15, 13, startTime); // 6-9 months - 15M tokens
        startTime = _pushEmissionSchedule(20, 13, startTime); // 9-12 months - 20M tokens
        startTime = _pushEmissionSchedule(20, 13, startTime); // 12-15 months - 20M tokens
        startTime = _pushEmissionSchedule(20, 13, startTime); // 15-18 months - 20M tokens
        startTime = _pushEmissionSchedule(20, 13, startTime); // 18-21 months - 20M tokens
        startTime = _pushEmissionSchedule(20, 13, startTime); // 21-24 months - 20M tokens

        // Years 2-20 - 104 week periods
        startTime = _pushEmissionSchedule(80, 104, startTime); // 2-4 years - 80M tokens
        startTime = _pushEmissionSchedule(40, 104, startTime); // 4-6 years - 40M tokens
        startTime = _pushEmissionSchedule(20, 104, startTime); // 6-8 years - 20M tokens
        startTime = _pushEmissionSchedule(20, 104, startTime); // 8-10 years - 20M tokens
        startTime = _pushEmissionSchedule(15, 104, startTime); // 10-12 years - 15M tokens
        startTime = _pushEmissionSchedule(15, 104, startTime); // 12-14 years - 15M tokens
        startTime = _pushEmissionSchedule(10, 104, startTime); // 14-16 years - 10M tokens
        startTime = _pushEmissionSchedule(10, 104, startTime); // 16-18 years - 10M tokens
        startTime = _pushEmissionSchedule(10, 104, startTime); // 18-20 years - 10M tokens
    }

    function getEmissionSchedules() public view returns (EmissionSchedule[] memory schedule) {
        return emissionSchedules;
    }

    /// @notice Calculate pending emission amount
    /// @return amount Total tokens to be emitted
    function getPendingEmission() public view returns (uint256 amount) {
        if (block.timestamp <= lastEmissionTime) return 0;

        uint256 elapsedWeeks = (block.timestamp - lastEmissionTime) / WEEK;
        if (elapsedWeeks == 0) return 0;

        for (uint256 i = 0; i < emissionSchedules.length; i++) {
            EmissionSchedule memory schedule = emissionSchedules[i];

            // Skip if schedule hasn't started
            if (block.timestamp < schedule.startTime) continue;

            uint256 scheduleEndTime = schedule.startTime + (schedule.durationWeeks * WEEK);

            // Skip if we're past this schedule's end time
            if (lastEmissionTime >= scheduleEndTime) continue;

            // Calculate weeks within this schedule's bounds
            uint256 effectiveStartTime = Math.max(lastEmissionTime, schedule.startTime);
            uint256 effectiveEndTime = Math.min(block.timestamp, scheduleEndTime);

            // Calculate actual weeks to count based on effective times
            uint256 weeksToCount;
            if (effectiveStartTime >= schedule.startTime) {
                // If we're starting within this schedule period
                weeksToCount = (effectiveEndTime - effectiveStartTime) / WEEK;
            } else {
                // If we're starting before this schedule period
                weeksToCount = (effectiveEndTime - schedule.startTime) / WEEK;
            }

            if (weeksToCount > 0) {
                amount += schedule.tokensPerWeek * weeksToCount;
            }
        }
    }

    /// @notice Emit tokens according to schedule
    function emitTokens() public {
        uint256 amount = getPendingEmission();
        require(amount > 0, "No pending emissions");

        lastEmissionTime = block.timestamp - (block.timestamp % WEEK);

        // Execute the transfer through the Safe
        require(
            ModuleManager(safe).execTransactionFromModule(
                address(token),
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, emissionAddress, amount),
                Enum.Operation.Call
            ),
            "Token transfer failed"
        );

        emit TokensEmitted(amount, emissionAddress);
    }

    /// @notice Update emission address
    /// @param _newEmissionAddress New address to receive emissions
    function updateEmissionAddress(address _newEmissionAddress) external onlyOwner {
        require(_newEmissionAddress != address(0), "Invalid address");

        // Emit any pending tokens to existing address
        uint256 pendingAmount = getPendingEmission();
        if (pendingAmount > 0) {
            emitTokens();
        }

        address oldAddress = emissionAddress;
        emissionAddress = _newEmissionAddress;
        emit EmissionAddressUpdated(oldAddress, _newEmissionAddress);
    }
}
