pragma solidity 0.8.18;

import "./TestContracts/DevTestSetup.sol";

contract Redemptions is DevTestSetup {
    function testRedemptionIsInOrderOfInterestRate() public {
        (uint256 coll,, TroveIDs memory troveIDs) = _setupForRedemption();

        uint256 debt_A = troveManager.getTroveEntireDebt(troveIDs.A);
        uint256 debt_B = troveManager.getTroveEntireDebt(troveIDs.B);
        uint256 debt_C = troveManager.getTroveEntireDebt(troveIDs.C);
        uint256 debt_D = troveManager.getTroveEntireDebt(troveIDs.D);

        // E redeems enough to fully redeem A and partially from B
        uint256 redeemAmount_1 = debt_A + debt_B / 2;
        redeem(E, redeemAmount_1);

        // Check A's Trove debt equals zero
        assertEq(troveManager.getTroveEntireDebt(troveIDs.A), 0, "A debt should be zero");
        // Check B coll and debt reduced
        assertLt(troveManager.getTroveEntireDebt(troveIDs.B), debt_B, "B debt should have reduced");
        assertLt(troveManager.getTroveEntireColl(troveIDs.B), coll, "B coll should have reduced");
        // Check C coll and debt unchanged
        assertEq(troveManager.getTroveEntireDebt(troveIDs.C), debt_C, "C debt should be unchanged");
        assertEq(troveManager.getTroveEntireColl(troveIDs.C), coll, "C coll should be unchanged");
        // Check D coll and debt unchanged
        assertEq(troveManager.getTroveEntireDebt(troveIDs.D), debt_D, "D debt should be unchanged");
        assertEq(troveManager.getTroveEntireColl(troveIDs.D), coll, "D coll should be unchanged");

        // E redeems enough to fully redeem B and partially redeem C
        uint256 redeemAmount_2 = debt_B / 2 + debt_C / 2;
        redeem(E, redeemAmount_2);

        // Check B's Trove debt equals zero
        assertEq(troveManager.getTroveEntireDebt(troveIDs.B), 0, "A debt should be zero");
        // Check C coll and debt reduced
        assertLt(troveManager.getTroveEntireDebt(troveIDs.C), debt_C, "C debt should have reduced");
        assertLt(troveManager.getTroveEntireColl(troveIDs.C), coll, "C coll should have reduced");
        // Check D coll and debt unchanged
        assertEq(troveManager.getTroveEntireDebt(troveIDs.D), debt_D, "D debt should be unchanged");
        assertEq(troveManager.getTroveEntireColl(troveIDs.D), coll, "D coll should be unchanged");
    }

    // - Troves can be redeemed down to zero
    function testFullRedemptionDoesntCloseTroves() public {
        (,, TroveIDs memory troveIDs) = _setupForRedemption();

        uint256 debt_A = troveManager.getTroveEntireDebt(troveIDs.A);
        uint256 debt_B = troveManager.getTroveEntireDebt(troveIDs.B);

        // E redeems enough to fully redeem A and B
        uint256 redeemAmount_1 = debt_A + debt_B;
        redeem(E, redeemAmount_1);

        // Check A and B still open
        assertEq(troveManager.getTroveStatus(troveIDs.A), 1); // Status active
        assertEq(troveManager.getTroveStatus(troveIDs.B), 1); // Status active
    }

    function testFullRedemptionLeavesTrovesWithDebtEqualToGasComp() public {
        (,, TroveIDs memory troveIDs) = _setupForRedemption();

        uint256 debt_A = troveManager.getTroveEntireDebt(troveIDs.A);
        uint256 debt_B = troveManager.getTroveEntireDebt(troveIDs.B);

        // E redeems enough to fully redeem A and B
        uint256 redeemAmount_1 = debt_A + debt_B;
        redeem(E, redeemAmount_1);

        // Check A and B's Trove debt equals zero
        assertEq(troveManager.getTroveEntireDebt(troveIDs.A), 0);
        assertEq(troveManager.getTroveEntireDebt(troveIDs.B), 0);
    }

    function testFullRedemptionSkipsTrovesAtGasCompDebt() public {
        (uint256 coll,, TroveIDs memory troveIDs) = _setupForRedemption();

        uint256 debt_A = troveManager.getTroveEntireDebt(troveIDs.A);
        uint256 debt_B = troveManager.getTroveEntireDebt(troveIDs.B);
        uint256 debt_C = troveManager.getTroveEntireDebt(troveIDs.C);

        // E redeems enough to fully redeem A and B
        uint256 redeemAmount_1 = debt_A + debt_B;
        redeem(E, redeemAmount_1);

        // Check A and B's Trove debt equals zero
        assertEq(troveManager.getTroveEntireDebt(troveIDs.A), 0);
        assertEq(troveManager.getTroveEntireDebt(troveIDs.B), 0);

        // E redeems again, enough to partially redeem C
        uint256 redeemAmount_2 = debt_C / 2;
        redeem(E, redeemAmount_2);

        // Check A and B still open with debt == zero
        assertEq(troveManager.getTroveStatus(troveIDs.A), 1); // Status active
        assertEq(troveManager.getTroveStatus(troveIDs.B), 1); // Status active
        assertEq(troveManager.getTroveEntireDebt(troveIDs.A), 0);
        assertEq(troveManager.getTroveEntireDebt(troveIDs.B), 0);

        // Check C's debt and coll reduced
        assertLt(troveManager.getTroveEntireDebt(troveIDs.C), debt_C);
        assertLt(troveManager.getTroveEntireColl(troveIDs.C), coll);
    }

    // - Accrued Trove interest contributes to redee into debt of a redeemed trove

    function testRedemptionIncludesAccruedTroveInterest() public {
        (,, TroveIDs memory troveIDs) = _setupForRedemption();

        (,, uint256 redistDebtGain_A,, uint256 accruedInterest_A) = troveManager.getEntireDebtAndColl(troveIDs.A);
        assertGt(accruedInterest_A, 0);
        assertEq(redistDebtGain_A, 0);

        troveManager.getTroveEntireDebt(troveIDs.A);
        uint256 debt_B = troveManager.getTroveEntireDebt(troveIDs.B);

        // E redeems again, enough to fully redeem A (recorded debt + interest), without touching the next trove B
        uint256 redeemAmount = troveManager.getTroveDebt(troveIDs.A) + accruedInterest_A;
        redeem(E, redeemAmount);

        // Check A reduced down to zero
        assertEq(troveManager.getTroveEntireDebt(troveIDs.A), 0);

        // Check B's debt unchanged
        assertEq(troveManager.getTroveEntireDebt(troveIDs.B), debt_B);
    }

    // TODO:
    // individual Trove interest updates for redeemed Troves

    // -
}
