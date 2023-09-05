// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { InvariantTestBase } from "./InvariantTestBase.t.sol";

// These invariants assume no external transfers into the contract, so all balance-based
// invariants are asserted exactly.
contract BoundedInvariants_NoTransfers is InvariantTestBase {

    function invariant_G() external {
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 netBalance =
                conduit.totalDeposits(assets[i])
                - arrangerHandler.drawnFunds(assets[i])
                + arrangerHandler.returnedFunds(assets[i])
                - conduit.totalWithdrawals(assets[i]);

            assertEq(MockERC20(assets[i]).balanceOf(address(conduit)), netBalance);
        }
    }

    function invariant_H() external {
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(
                MockERC20(assets[i]).balanceOf(address(conduit)),
                conduit.availableFunds(assets[i]) + conduit.totalWithdrawableFunds(assets[i])
            );
        }
    }

}

// These invariants assume external transfers into the contract, so balance-based
// invariants are asserted with with gt/lt checks
contract BoundedInvariants_Transfers is InvariantTestBase {

    function setUp() public override {
        super.setUp();
        targetContract(address(transfererHandler));
    }

    function invariant_G() external {
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 netBalance =
                conduit.totalDeposits(assets[i])
                - arrangerHandler.drawnFunds(assets[i])
                + arrangerHandler.returnedFunds(assets[i])
                - conduit.totalWithdrawals(assets[i]);

            assertGe(MockERC20(assets[i]).balanceOf(address(conduit)), netBalance);
        }
    }

    function invariant_H() external {
        for (uint256 i = 0; i < assets.length; i++) {
            assertGe(
                MockERC20(assets[i]).balanceOf(address(conduit)),
                conduit.availableFunds(assets[i]) + conduit.totalWithdrawableFunds(assets[i])
            );
        }
    }

}

