// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

contract ArrangerConduit_WithdrawTests is ConduitAssetTestBase {

    // TODO: Determine if failure from insufficient balance is possible
    // TODO: Add test with over-limit request
    // TODO: Should we allow operators to withdraw from deposits?

    function test_withdraw_noIlkAuth() external {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);
        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.stopPrank();

        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.withdraw(ilk, address(asset), 100);
    }

    function test_withdraw_revertingTransfer() external {
        vm.mockCall(
            address(asset),
            abi.encodeWithSelector(asset.transfer.selector, operator, 0),
            abi.encode(false)
        );
        vm.prank(operator);
        vm.expectRevert("SafeERC20/transfer-failed");
        conduit.withdraw(ilk, address(asset), 0);
    }

    function test_withdraw_singleIlk() external {
        _depositAndDrawFunds(asset, operator, ilk, 100);

        vm.prank(operator);
        conduit.requestFunds(ilk, address(asset), 100, "info");

        asset.mint(address(conduit), 100);

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(operator),         0);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 100);
        assertEq(conduit.withdrawals(ilk, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),       0);

        vm.prank(operator);
        uint256 amount = conduit.withdraw(ilk, address(asset), 100);

        assertEq(amount, 100);

        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(operator),         100);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 0);
        assertEq(conduit.withdrawals(ilk, address(asset)),       100);
        assertEq(conduit.totalWithdrawals(address(asset)),       100);
    }

    function test_withdraw_multiIlk_over_under_partial_full_full() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        address operator1 = makeAddr("operator1");
        address operator2 = makeAddr("operator2");

        _setupOperatorRole(ilk1, operator1);
        _setupOperatorRole(ilk2, operator2);

        registry.file(ilk1, "buffer", operator1);
        registry.file(ilk2, "buffer", operator2);

        _depositAndDrawFunds(asset, operator1, ilk1, 100);
        _depositAndDrawFunds(asset, operator2, ilk2, 400);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset), 100, "info");

        vm.prank(operator2);
        conduit.requestFunds(ilk2, address(asset), 400, "info");

        asset.mint(address(conduit), 500);

        vm.startPrank(arranger);

        conduit.returnFunds(0, 200);  // Over by 100
        conduit.returnFunds(1, 300);  // Under by 100

        vm.stopPrank();

        assertEq(asset.balanceOf(address(conduit)), 500);
        assertEq(asset.balanceOf(operator1),        0);
        assertEq(asset.balanceOf(operator2),        0);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 200);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  500);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       0);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),        0);

        // Partial withdraw ilk 1

        vm.prank(operator1);
        uint256 amount = conduit.withdraw(ilk1, address(asset), 50);

        assertEq(amount, 50);

        assertEq(asset.balanceOf(address(conduit)), 450);
        assertEq(asset.balanceOf(operator1),        50);
        assertEq(asset.balanceOf(operator2),        0);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 150);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  450);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       50);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),        50);

        // Finish withdraw ilk 1

        vm.prank(operator1);
        amount = conduit.withdraw(ilk1, address(asset), 150);

        assertEq(amount, 150);

        assertEq(asset.balanceOf(address(conduit)), 300);
        assertEq(asset.balanceOf(operator1),        200);
        assertEq(asset.balanceOf(operator2),        0);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  300);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       200);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       0);
        assertEq(conduit.totalWithdrawals(address(asset)),        200);

        // Full withdraw ilk 2

        vm.prank(operator2);
        amount = conduit.withdraw(ilk2, address(asset), 300);

        assertEq(amount, 300);

        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(operator1),        200);
        assertEq(asset.balanceOf(operator2),        300);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  0);
        assertEq(conduit.withdrawals(ilk1, address(asset)),       200);
        assertEq(conduit.withdrawals(ilk2, address(asset)),       300);
        assertEq(conduit.totalWithdrawals(address(asset)),        500);
    }

}
