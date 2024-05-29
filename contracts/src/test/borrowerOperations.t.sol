pragma solidity ^0.8.18;

import "./TestContracts/DevTestSetup.sol";

contract BorrowerOperationsTest is DevTestSetup {
    function testCloseLastTroveReverts() public {
        priceFeed.setPrice(2000e18);
        uint256 ATroveId = openTroveNoHints100pct(A, 100 ether, 100000e18, 1e17);

        // Artificially mint to Alice so she has enough to close her trove
        uint256 aliceDebt = troveManager.getTroveEntireDebt(ATroveId);
        deal(address(boldToken), A, aliceDebt);

        // check is not below CT
        checkBelowCriticalThreshold(false);

        // Alice attempts to close her trove
        vm.startPrank(A);
        vm.expectRevert("TroveManager: Only one trove in the system");
        borrowerOperations.closeTrove(ATroveId);
        vm.stopPrank();
    }

    function testRepayingTooMuchDebtReverts() public {
        uint256 troveId = openTroveNoHints100pct(A, 100 ether, 2_000 ether, 0.01 ether);
        deal(address(boldToken), A, 1_000 ether);
        vm.prank(A);
        vm.expectRevert("BorrowerOps: Amount repaid must not be larger than the Trove's debt");
        borrowerOperations.repayBold(troveId, 3_000 ether);
    }

    function testWithdrawingTooMuchCollateralReverts() public {
        uint256 troveId = openTroveNoHints100pct(A, 100 ether, 2_000 ether, 0.01 ether);
        vm.prank(A);
        vm.expectRevert("BorrowerOps: Can't withdraw more than the Trove's entire collateral");
        borrowerOperations.withdrawColl(troveId, 200 ether);
    }

    function testOpenTroveChargesUpfrontFee() public {
        uint256 borrow = 10_000 ether;
        uint256 interestRate = 0.05 ether;

        uint256 upfrontFee = predictOpenTroveUpfrontFee(borrow, interestRate);
        assertGt(upfrontFee, 0);

        uint256 activePoolDebtBefore = activePool.getBoldDebt();

        vm.prank(A);
        uint256 troveId = borrowerOperations.openTrove(A, 0, 100 ether, borrow, 0, 0, interestRate, upfrontFee);

        uint256 troveDebt = troveManager.getTroveEntireDebt(troveId);
        uint256 activePoolDebtAfter = activePool.getBoldDebt();

        uint256 expectedDebt = borrow + BOLD_GAS_COMP + upfrontFee;
        assertEqDecimal(troveDebt, expectedDebt, 18, "Wrong Trove debt");
        assertEqDecimal(activePoolDebtAfter - activePoolDebtBefore, expectedDebt, 18, "Wrong AP debt increase");
    }

    function testWithdrawBoldChargesUpfrontFee() public {
        uint256 troveId = openTroveNoHints100pct(A, 100 ether, 10_000 ether, 0.05 ether);

        uint256 withdrawal = 1_000 ether;

        uint256 upfrontFee = predictAdjustTroveUpfrontFee(troveId, withdrawal);
        assertGt(upfrontFee, 0);

        uint256 troveDebtBefore = troveManager.getTroveEntireDebt(troveId);
        uint256 activePoolDebtBefore = activePool.getBoldDebt();

        vm.prank(A);
        borrowerOperations.withdrawBold(troveId, withdrawal, upfrontFee);

        uint256 troveDebtAfter = troveManager.getTroveEntireDebt(troveId);
        uint256 activePoolDebtAfter = activePool.getBoldDebt();

        uint256 expectedDebtIncrease = withdrawal + upfrontFee;
        assertEqDecimal(troveDebtAfter - troveDebtBefore, expectedDebtIncrease, 18, "Wrong Trove debt increase");
        assertEqDecimal(activePoolDebtAfter - activePoolDebtBefore, expectedDebtIncrease, 18, "Wrong AP debt increase");
    }

    function testAdjustInterestRateChargesUpfrontFeeWhenPremature() public {
        uint256 troveId = openTroveNoHints100pct(A, 100 ether, 10_000 ether, 0.05 ether);

        uint56[3] memory interestRate = [0.01 ether, 0.02 ether, 0.03 ether];

        uint256 troveDebtBefore = troveManager.getTroveEntireDebt(troveId);
        uint256 activePoolDebtBefore = activePool.getBoldDebt();

        // First adjustment is free, but it will start a cooldown timer
        vm.prank(A);
        borrowerOperations.adjustTroveInterestRate(troveId, interestRate[0], 0, 0, 0);

        uint256 troveDebtAfter = troveManager.getTroveEntireDebt(troveId);
        uint256 activePoolDebtAfter = activePool.getBoldDebt();

        assertEqDecimal(troveDebtAfter - troveDebtBefore, 0, 18, "Wrong Trove debt increase 1");
        assertEqDecimal(activePoolDebtAfter - activePoolDebtBefore, 0, 18, "Wrong AP debt increase 1");

        // Wait less than the cooldown period, thus the next adjustment will have a cost
        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN / 2);

        uint256 upfrontFee = predictAdjustInterestRateUpfrontFee(troveId, interestRate[1]);
        assertGt(upfrontFee, 0);

        troveDebtBefore = troveManager.getTroveEntireDebt(troveId);
        activePoolDebtBefore = activePool.getBoldDebt();

        vm.prank(A);
        borrowerOperations.adjustTroveInterestRate(troveId, interestRate[1], 0, 0, upfrontFee);

        troveDebtAfter = troveManager.getTroveEntireDebt(troveId);
        activePoolDebtAfter = activePool.getBoldDebt();

        assertEqDecimal(troveDebtAfter - troveDebtBefore, upfrontFee, 18, "Wrong Trove debt increase 2");
        assertEqDecimal(activePoolDebtAfter - activePoolDebtBefore, upfrontFee, 18, "Wrong AP debt increase 2");

        // Wait for cooldown to finish, thus the next adjustment will be free again
        vm.warp(block.timestamp + INTEREST_RATE_ADJ_COOLDOWN / 2);

        troveDebtBefore = troveManager.getTroveEntireDebt(troveId);
        activePoolDebtBefore = activePool.getBoldDebt();

        vm.prank(A);
        borrowerOperations.adjustTroveInterestRate(troveId, interestRate[2], 0, 0, 0);

        troveDebtAfter = troveManager.getTroveEntireDebt(troveId);
        activePoolDebtAfter = activePool.getBoldDebt();

        assertEqDecimal(troveDebtAfter - troveDebtBefore, 0, 18, "Wrong Trove debt increase 3");
        assertEqDecimal(activePoolDebtAfter - activePoolDebtBefore, 0, 18, "Wrong AP debt increase 3");
    }
}
