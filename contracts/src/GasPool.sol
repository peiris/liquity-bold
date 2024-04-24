// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "./Interfaces/IBorrowerOperations.sol";
import "./Interfaces/ITroveManager.sol";

/**
 * The purpose of this contract is to hold collateral tokens for gas compensation:
 * https://github.com/liquity/bold#gas-compensation
 * When a borrower opens a trove, an additional COLL_GASPOOL_COMPENSATION ETH coll is pulled,
 * and sent to this contract.
 * When a borrower closes their active trove, this gas compensation is refunded:
 * COLL_GASPOOL_COMPENSATION collateral is sent from this contract to the owner
 * See this issue for more context: https://github.com/liquity/bold/issues/53
 */
contract GasPool {
    constructor(IERC20 _ETH, IBorrowerOperations _borrowerOperations, ITroveManager _troveManager) {
        // Approve BorrowerOperetaions (close trove) and TroveManager (liquidate trove) to pull gas compensation
        _ETH.approve(address(_borrowerOperations), type(uint256).max);
        _ETH.approve(address(_troveManager), type(uint256).max);
    }
}
