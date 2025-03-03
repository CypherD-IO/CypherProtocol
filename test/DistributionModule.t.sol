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

    /// @notice start time of the distribution schedule
    uint256 public startTime = 2002;

    function setUp() public {
        token = new MockToken();
        safe = new MockSafe();
        owner = address(this);
        emissionAddress = address(0xE1);

        module = new DistributionModule(owner, address(safe), address(token), emissionAddress, startTime);
        vm.warp(startTime);

        // Enable module in Safe
        safe.enableModuleMock(address(module));

        // Transfer tokens to Safe
        token.transfer(address(safe), token.totalSupply());
    }

    function testConstruction() public view {
        assertEq(module.owner(), owner, "owner incorrect");
        assertEq(address(module.token()), address(token), "token address incorrect");
        assertEq(address(module.safe()), address(safe), "safe address incorrect");
        assertEq(module.emissionAddress(), emissionAddress, "emission address incorrect");
        assertEq(module.lastEmissionTime(), startTime, "last emission time incorrect");
    }

    function testConstructionReverts() public {
        vm.expectRevert("Invalid Safe address");
        new DistributionModule(owner, address(0), address(token), emissionAddress, 0);

        vm.expectRevert("Invalid token address");
        new DistributionModule(owner, address(safe), address(0), emissionAddress, 0);

        vm.expectRevert("Invalid emission address");
        new DistributionModule(owner, address(safe), address(token), address(0), 0);

        vm.expectRevert("Invalid start time");
        new DistributionModule(owner, address(safe), address(token), address(1), 0);
    }

    function testInitialSchedule() public view {
        // Test first schedule (0-3 months)
        DistributionModule.EmissionSchedule[] memory schedules = module.getEmissionSchedules();
        DistributionModule.EmissionSchedule memory schedule = schedules[0];

        assertEq(schedule.startTime, block.timestamp, "incorrect start time 0");
        assertEq(schedule.tokensPerWeek, 5 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 13, "incorrect duration weeks");

        // Test second schedule (3-6 months)
        schedule = schedules[1];
        assertEq(schedule.startTime, block.timestamp + (13 * 1 weeks), "incorrect start time 1");
        assertEq(schedule.tokensPerWeek, 10 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 13, "incorrect duration weeks");

        // Test middle schedule (6-9 months)
        schedule = schedules[2];
        assertEq(schedule.startTime, block.timestamp + (26 * 1 weeks), "incorrect start time 2");
        assertEq(schedule.tokensPerWeek, 15 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 13, "incorrect duration weeks");

        // Test middle schedule (9 months - 2 years)
        schedule = schedules[3];
        assertEq(schedule.startTime, block.timestamp + (39 * 1 weeks), "incorrect start time 3");
        assertEq(schedule.tokensPerWeek, 100 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 65, "incorrect duration weeks");

        // Test middle schedule (2-4 years)
        schedule = schedules[4];
        assertEq(schedule.startTime, block.timestamp + (104 * 1 weeks), "incorrect start time 4");
        assertEq(schedule.tokensPerWeek, 80 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 104, "incorrect duration weeks");

        // Test last schedule (4-6 years)
        schedule = schedules[5];
        assertEq(schedule.startTime, block.timestamp + (208 * 1 weeks), "incorrect start time 5");
        assertEq(schedule.tokensPerWeek, 40 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 104, "incorrect duration weeks");

        // Test last schedule (6-10 years)
        schedule = schedules[6];
        assertEq(schedule.startTime, block.timestamp + 312 * 1 weeks, "incorrect start time 6");
        assertEq(schedule.tokensPerWeek, 40 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 208, "incorrect duration weeks");

        // Test last schedule (10-14 years)
        schedule = schedules[7];
        assertEq(schedule.startTime, block.timestamp + 520 * 1 weeks, "incorrect start time 7");
        assertEq(schedule.tokensPerWeek, 30 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 208, "incorrect duration weeks");

        // Test last schedule (14-20 years)
        schedule = schedules[8];
        assertEq(schedule.startTime, block.timestamp + 728 * 1 weeks, "incorrect start time 8");
        assertEq(schedule.tokensPerWeek, 30 * 1_000_000e18 / schedule.durationWeeks, "incorrect tokens per week");
        assertEq(schedule.durationWeeks, 312, "incorrect duration weeks");
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
        assertEq(module.getPendingEmission(), schedule[0].tokensPerWeek, "incorrect tokens in pending emissions");
    }

    function testPendingEmissionsMultipleWeeks() public {
        // Warp 3 weeks
        vm.warp(block.timestamp + 3 weeks);

        // Should get 3 weeks of emissions from first schedule
        DistributionModule.EmissionSchedule[] memory schedule = module.getEmissionSchedules();
        assertEq(
            module.getPendingEmission(),
            schedule[0].tokensPerWeek * 3,
            "incorrect tokens in pending emissions, should be 3 weeks"
        );
    }

    function testEmitTokens() public {
        // Warp 2 weeks to accumulate some emissions
        vm.warp(block.timestamp + 2 weeks);

        uint256 expectedAmount = module.getPendingEmission();
        assertGt(expectedAmount, 0, "expected amount not gt 0");

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
        assertEq(module.emissionAddress(), newEmissionAddress, "emission address incorrect");

        // Verify pending tokens were emitted to old address
        assertEq(token.balanceOf(emissionAddress), pendingAmount, "pending amount incorrect");

        // Warp again and verify new emissions go to new address
        vm.warp(block.timestamp + 1 weeks + 1);
        module.emitTokens();
        assertEq(
            token.balanceOf(newEmissionAddress),
            module.getEmissionSchedules()[0].tokensPerWeek,
            "tokens per week not distributed"
        );
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
        assertEq(module.getPendingEmission(), schedule.tokensPerWeek, "emissions incorrect at week 1.5");
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
