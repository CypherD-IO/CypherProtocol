// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "lib/safe-contracts/contracts/base/ModuleManager.sol";

import "../src/DistributionModule.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000_000 * 1e18);
    }
}

contract MockSafe is ModuleManager {
    constructor() {}

    // Allow the test contract to enable modules
    function enableModuleMock(address module) external {
        modules[SENTINEL_MODULES] = module;
        modules[module] = SENTINEL_MODULES;
    }
}

contract DistributionModuleTest is Test {
    DistributionModule module;
    MockToken token;
    MockSafe safe;
    address emissionAddress;
    address owner;

    /// @notice Emitted when tokens are distributed
    event TokensEmitted(uint256 amount, address recipient);

    /// @notice Emitted when emission address is updated
    event EmissionAddressUpdated(address oldAddress, address newAddress);

    function setUp() public {
        token = new MockToken();
        safe = new MockSafe();
        owner = address(this);
        emissionAddress = address(0xE1);

        module = new DistributionModule(owner, address(safe), address(token), emissionAddress);

        // Enable module in Safe
        safe.enableModuleMock(address(module));

        // Transfer tokens to Safe
        token.transfer(address(safe), token.totalSupply());
    }

    function testConstruction() public {
        assertEq(module.owner(), owner);
        assertEq(address(module.token()), address(token));
        assertEq(address(module.safe()), address(safe));
        assertEq(module.emissionAddress(), emissionAddress);
        assertEq(module.lastEmissionTime(), block.timestamp);
    }

    function testConstructionReverts() public {
        vm.expectRevert("Invalid Safe address");
        new DistributionModule(owner, address(0), address(token), emissionAddress);

        vm.expectRevert("Invalid token address");
        new DistributionModule(owner, address(safe), address(0), emissionAddress);

        vm.expectRevert("Invalid emission address");
        new DistributionModule(owner, address(safe), address(token), address(0));
    }

    function testInitialSchedule() public {
        // Test first schedule (0-3 months)
        DistributionModule.EmissionSchedule[] memory schedules = module.getEmissionSchedules();
        DistributionModule.EmissionSchedule memory schedule = schedules[0];

        assertEq(schedule.startTime, block.timestamp);
        assertEq(schedule.tokensPerWeek, 5 * 1_000_000e18);
        assertEq(schedule.durationWeeks, 13);

        // Test middle schedule (2-4 years)
        schedule = schedules[8];
        assertEq(schedule.startTime, block.timestamp + (13 * 8 * 1 weeks));
        assertEq(schedule.tokensPerWeek, 80 * 1_000_000e18);
        assertEq(schedule.durationWeeks, 104);

        // Test last schedule (18-20 years)
        schedule = schedules[16];
        assertEq(schedule.startTime, block.timestamp + (13 * 8 * 1 weeks) + (104 * 8 * 1 weeks));
        assertEq(schedule.tokensPerWeek, 10 * 1_000_000e18);
        assertEq(schedule.durationWeeks, 104);
    }

    function testNoPendingEmissionsBeforeTime() public {
        assertEq(module.getPendingEmission(), 0);

        // Warp to just before a week passes
        vm.warp(block.timestamp + 1 weeks - 1);
        assertEq(module.getPendingEmission(), 0);
    }

    function testPendingEmissionsSingleWeek() public {
        // Warp exactly one week
        vm.warp(block.timestamp + 1 weeks);

        // Should get first week's emission from first schedule
        DistributionModule.EmissionSchedule[] memory schedule = module.getEmissionSchedules();
        assertEq(module.getPendingEmission(), schedule[0].tokensPerWeek);
    }

    function testPendingEmissionsMultipleWeeks() public {
        // Warp 3 weeks
        vm.warp(block.timestamp + 3 weeks);

        // Should get 3 weeks of emissions from first schedule
        DistributionModule.EmissionSchedule[] memory schedule = module.getEmissionSchedules();
        assertEq(module.getPendingEmission(), schedule[0].tokensPerWeek * 3);
    }

    function testEmitTokens() public {
        // Warp 2 weeks to accumulate some emissions
        vm.warp(block.timestamp + 2 weeks);

        uint256 expectedAmount = module.getPendingEmission();
        assertTrue(expectedAmount > 0);

        uint256 balanceBefore = token.balanceOf(emissionAddress);

        // Emit tokens
        module.emitTokens();

        // Verify tokens were transferred
        assertEq(token.balanceOf(emissionAddress) - balanceBefore, expectedAmount);

        // Verify lastEmissionTime was updated
        assertEq(module.lastEmissionTime(), block.timestamp - (block.timestamp % 1 weeks));

        // Verify no pending emissions
        assertEq(module.getPendingEmission(), 0);
    }

    function testEmitTokensRevertsWhenNoPending() public {
        vm.expectRevert("No pending emissions");
        module.emitTokens();
    }

    function testUpdateEmissionAddress() public {
        address newEmissionAddress = address(0xE2);

        // Warp to accumulate some emissions
        vm.warp(block.timestamp + 1 weeks);
        uint256 pendingAmount = module.getPendingEmission();

        // Update emission address
        module.updateEmissionAddress(newEmissionAddress);

        // Verify address was updated
        assertEq(module.emissionAddress(), newEmissionAddress);

        // Verify pending tokens were emitted to old address
        assertEq(token.balanceOf(emissionAddress), pendingAmount);

        // Warp again and verify new emissions go to new address
        vm.warp(block.timestamp + 1 weeks + 1);
        module.emitTokens();
        assertEq(token.balanceOf(newEmissionAddress), module.getEmissionSchedules()[0].tokensPerWeek);
    }

    function testUpdateEmissionAddressRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid address");
        module.updateEmissionAddress(address(0));
    }

    function testCrossScheduleEmissions() public {
        // Warp to end of first schedule
        vm.warp(block.timestamp + 13 weeks);

        // Should get full first schedule emissions
        DistributionModule.EmissionSchedule memory schedule1 = module.getEmissionSchedules()[0];
        assertEq(module.getPendingEmission(), schedule1.tokensPerWeek * 13, "emissions incorrect in first 13 weeks");

        // Emit tokens
        module.emitTokens();

        // Warp 2 weeks into second schedule
        vm.warp(block.timestamp + 2 weeks);

        // Should get 2 weeks of second schedule emissions
        DistributionModule.EmissionSchedule memory schedule2 = module.getEmissionSchedules()[1];
        assertEq(module.getPendingEmission(), schedule2.tokensPerWeek * 2, "emissions incorrect in weeks 14-15");
    }

    function testPartialWeekEmissions() public {
        // Warp 1.5 weeks
        vm.warp(block.timestamp + 1.5 weeks);

        // Should only get 1 week of emissions
        DistributionModule.EmissionSchedule memory schedule = module.getEmissionSchedules()[0];
        assertEq(module.getPendingEmission(), schedule.tokensPerWeek);
    }

    function testEmissionEventEmitted() public {
        // Warp to accumulate emissions
        vm.warp(block.timestamp + 1 weeks);

        uint256 expectedAmount = module.getPendingEmission();

        vm.expectEmit(true, true, false, true);
        emit TokensEmitted(expectedAmount, emissionAddress);
        module.emitTokens();
    }

    function testEmissionAddressUpdateEventEmitted() public {
        address newEmissionAddress = address(0xE2);

        vm.expectEmit(true, true, false, true);
        emit EmissionAddressUpdated(emissionAddress, newEmissionAddress);
        module.updateEmissionAddress(newEmissionAddress);
    }

    function testEmitTokensRevertsWhenSafeHasInsufficientBalance() public {
        // Warp to accumulate emissions
        vm.warp(block.timestamp + 1 weeks);

        // Transfer all tokens out of Safe
        vm.startPrank(address(safe));
        token.transfer(address(0xdead), token.balanceOf(address(safe)));
        vm.stopPrank();

        // Try to emit tokens
        vm.expectRevert("Token transfer failed");
        module.emitTokens();
    }
}
