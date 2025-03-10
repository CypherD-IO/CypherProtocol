// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
    uint256 public startTime;

    function setUp() public {
        token = new MockToken();
        safe = new MockSafe();
        owner = address(this);
        emissionAddress = address(0xE1);

        // Set startTime to a future week boundary
        startTime = (block.timestamp / 1 weeks + 1) * 1 weeks;

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

    function testUpdateEmissionAddressRevertsOnNonOwnerCall() public {
        vm.prank(address(100_000_000));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(100_000_000)));
        module.updateEmissionAddress(address(1));
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

    function testTotalEmissionAmount() public {
        DistributionModule.EmissionSchedule[] memory schedules = module.getEmissionSchedules();
        DistributionModule.EmissionSchedule memory last = schedules[schedules.length - 1];
        uint256 endTime = last.startTime + last.durationWeeks * 1 weeks + 1;
        vm.warp(endTime);

        uint256 balanceBefore = token.balanceOf(emissionAddress);

        module.emitTokens();

        uint256 totalEmitted = token.balanceOf(emissionAddress) - balanceBefore;

        _checkTotalTokensEmitted(totalEmitted);
    }

    function testEmitTokensForAllSchedules() public {
        DistributionModule.EmissionSchedule[] memory schedules = module.getEmissionSchedules();
        uint256 totalEmitted = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            DistributionModule.EmissionSchedule memory schedule = schedules[i];

            // Warp to the end of this schedule
            uint256 scheduleEndTime = schedule.startTime + (schedule.durationWeeks * 1 weeks);
            vm.warp(scheduleEndTime);

            // Record balance before emission
            uint256 balanceBefore = token.balanceOf(emissionAddress);

            // Emit tokens
            module.emitTokens();

            // Calculate actual emitted amount
            uint256 emittedAmount = token.balanceOf(emissionAddress) - balanceBefore;
            totalEmitted += emittedAmount;

            // Calculate expected emission for this schedule period
            uint256 expectedEmission = schedule.tokensPerWeek * schedule.durationWeeks;

            // Verify tokens were transferred correctly
            assertEq(
                emittedAmount,
                expectedEmission,
                string(abi.encodePacked("Schedule ", vm.toString(i), " emission incorrect"))
            );

            // Verify lastEmissionTime was updated correctly
            assertEq(module.lastEmissionTime(), scheduleEndTime - (scheduleEndTime % 1 weeks));
        }

        _checkTotalTokensEmitted(totalEmitted);
    }

    function _checkTotalTokensEmitted(uint256 totalEmitted) private pure {
        // Verify total emissions match expected amount
        assertLe(totalEmitted, 350_000_000 * 1e18, "exceeded max emission amount");
        assertGt(totalEmitted, 350_000_000 * 1e18 - 1e3, "emitted too few tokens");
        assertEq(totalEmitted, 349_999_999.99999999999999926e18, "incorrect tokens emitted");
    }

    function testUpdateEmissionAddressWithNoPendingEmissions() public {
        address newEmissionAddress = address(0xE2);

        // Ensure there are no pending emissions (we're at the start time)
        assertEq(module.getPendingEmission(), 0, "Should be no pending emissions");

        // Get initial balance of emission address
        uint256 initialBalance = token.balanceOf(emissionAddress);

        // Update emission address
        vm.expectEmit(true, true, false, true);
        emit EmissionAddressUpdated(emissionAddress, newEmissionAddress);
        module.updateEmissionAddress(newEmissionAddress);

        // Verify address was updated
        assertEq(module.emissionAddress(), newEmissionAddress, "Emission address not updated");

        // Verify no tokens were transferred (since there were no pending emissions)
        assertEq(token.balanceOf(emissionAddress), initialBalance, "Balance should not change");

        // Verify lastEmissionTime was not updated
        assertEq(module.lastEmissionTime(), startTime, "Last emission time should not change");
    }

    function testConstructorStartTimeValidation() public {
        // Store current block timestamp
        uint256 currentTime = block.timestamp;

        // Calculate next week boundary
        uint256 nextWeekBoundary = (currentTime / 1 weeks + 1) * 1 weeks;

        // Try to create with current timestamp (should fail)
        vm.expectRevert("Invalid start time");
        new DistributionModule(owner, address(safe), address(token), emissionAddress, currentTime);

        // Try to create with past timestamp (should fail)
        vm.expectRevert("Invalid start time");
        new DistributionModule(owner, address(safe), address(token), emissionAddress, currentTime - 1);

        // Try to create with future timestamp but not week boundary (should fail)
        vm.expectRevert("Start time must be at week boundary");
        new DistributionModule(owner, address(safe), address(token), emissionAddress, nextWeekBoundary + 1);

        // Create with future week boundary timestamp (should succeed)
        DistributionModule validModule =
            new DistributionModule(owner, address(safe), address(token), emissionAddress, nextWeekBoundary);

        // Verify the module was created with correct lastEmissionTime
        assertEq(validModule.lastEmissionTime(), nextWeekBoundary, "Last emission time incorrect");
    }

    function testScheduleBoundaryEdgeCases() public {
        DistributionModule.EmissionSchedule[] memory schedules = module.getEmissionSchedules();

        // Test exactly at the boundary between first and second schedule
        uint256 firstScheduleEnd = schedules[0].startTime + (schedules[0].durationWeeks * 1 weeks);

        // Warp to exactly the end of first schedule
        vm.warp(firstScheduleEnd);

        // Emit tokens for the first schedule
        uint256 expectedFirstAmount = schedules[0].tokensPerWeek * schedules[0].durationWeeks;
        uint256 balanceBefore = token.balanceOf(emissionAddress);
        module.emitTokens();
        uint256 actualFirstAmount = token.balanceOf(emissionAddress) - balanceBefore;

        // Verify correct amount was emitted
        assertEq(actualFirstAmount, expectedFirstAmount, "Incorrect emission at first schedule boundary");

        // Verify lastEmissionTime is exactly at the schedule boundary
        assertEq(module.lastEmissionTime(), firstScheduleEnd, "Last emission time not at schedule boundary");

        // Now warp exactly one week into the second schedule
        vm.warp(firstScheduleEnd + 1 weeks);

        // Verify pending emission is exactly one week of second schedule
        uint256 pendingAmount = module.getPendingEmission();
        assertEq(pendingAmount, schedules[1].tokensPerWeek, "Incorrect pending amount after schedule transition");

        // Emit tokens again
        balanceBefore = token.balanceOf(emissionAddress);
        module.emitTokens();
        uint256 actualSecondAmount = token.balanceOf(emissionAddress) - balanceBefore;

        // Verify correct amount was emitted for second schedule
        assertEq(actualSecondAmount, schedules[1].tokensPerWeek, "Incorrect emission after schedule transition");
    }

    function testExactScheduleBoundaryCalculation() public {
        DistributionModule.EmissionSchedule[] memory schedules = module.getEmissionSchedules();

        // For each schedule boundary, test the calculation
        for (uint256 i = 0; i < schedules.length - 1; i++) {
            // Calculate the boundary between current and next schedule
            uint256 scheduleBoundary = schedules[i].startTime + (schedules[i].durationWeeks * 1 weeks);

            // Verify this matches the start time of the next schedule
            assertEq(
                scheduleBoundary,
                schedules[i + 1].startTime,
                string(abi.encodePacked("Schedule boundary mismatch at index ", vm.toString(i)))
            );

            // Warp to 1 second before boundary
            vm.warp(scheduleBoundary - 1);

            // Get pending emissions (should be from current schedule)
            uint256 pendingBefore = module.getPendingEmission();

            // Warp to exactly at boundary
            vm.warp(scheduleBoundary);

            // Get pending emissions (should still be from current schedule)
            uint256 pendingAt = module.getPendingEmission();

            assertLt(
                pendingBefore, pendingAt, string.concat("Pending emissions changed at exact boundary ", vm.toString(i))
            );

            // Warp to 1 second after boundary
            vm.warp(scheduleBoundary + 1);

            // Get pending emissions (should still be the same since we need a full week)
            uint256 pendingAfter = module.getPendingEmission();
            assertEq(pendingAt, pendingAfter, "Pending emissions changed just after boundary");

            module.emitTokens();
        }
    }
}
