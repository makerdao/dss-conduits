// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../../lib/forge-std/src/console2.sol";

import { stdError } from "../../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_WithdrawTests is ConduitAssetTestBase {

    // TODO: Determine if failure from insufficient balance is possible
    // TODO: Add test with over-limit request

    function test_withdraw_singleIlk() external {
        _depositAndDrawFunds(asset, ilk, 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(address(this)),    0);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 100);
        assertEq(conduit.withdrawals(ilk, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),       0);

        uint256 amount = conduit.withdraw(ilk, address(asset), 100);

        assertEq(amount, 100);

        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(address(this)),    100);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 0);
        assertEq(conduit.withdrawals(ilk, address(asset)),       100);
        assertEq(conduit.totalWithdrawals(address(asset)),       100);
    }

    function test_withdraw_multiIlk_over_under_partial_full_full() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        _setupRoles(ilk1, address(this));
        _setupRoles(ilk2, address(this));

        registry.file(ilk1, "buffer", address(this));
        registry.file(ilk2, "buffer", address(this));

        _depositAndDrawFunds(asset, ilk1, 100);
        _depositAndDrawFunds(asset, ilk2, 400);

        conduit.requestFunds(ilk1, address(asset), 100, "info");
        conduit.requestFunds(ilk2, address(asset), 400, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 500);
        conduit.returnFunds(0, 200);  // Over by 100
        conduit.returnFunds(1, 300);  // Under by 100

        vm.stopPrank();

        assertEq(asset.balanceOf(address(conduit)), 500);
        assertEq(asset.balanceOf(address(this)),    0);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 200);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  500);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       0);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),        0);

        // Partial withdraw ilk 1

        uint256 amount = conduit.withdraw(ilk1, address(asset), 50);

        assertEq(amount, 50);

        assertEq(asset.balanceOf(address(conduit)), 450);
        assertEq(asset.balanceOf(address(this)),    50);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 150);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  450);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       50);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),        50);

        // Finish withdraw ilk 1

        amount = conduit.withdraw(ilk1, address(asset), 150);

        assertEq(amount, 150);

        assertEq(asset.balanceOf(address(conduit)), 300);
        assertEq(asset.balanceOf(address(this)),    200);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  300);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       200);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),        200);

        // Full withdraw ilk 2

        amount = conduit.withdraw(ilk2, address(asset), 300);

        assertEq(amount, 300);

        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(address(this)),    500);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  0);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       200);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       300);
        assertEq(conduit.totalWithdrawals(address(asset)),        500);
    }

}
