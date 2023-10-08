// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

contract ArrangerConduit_WithdrawTests is ConduitAssetTestBase {

    function test_withdraw_noIlkAuth() external {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        vm.stopPrank();

        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.withdraw(ilk1, address(asset1), 100);
    }

    function test_withdraw_moreThanWithdrawable() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        asset1.mint(address(conduit), 100);

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset1.balanceOf(buffer1),          0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  100);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       0);
        assertEq(conduit.totalWithdrawals(address(asset1)),        0);

        // Try to withdraw 200 when only 100 is available
        // (using instead of 101 to show its not because of rounding)
        vm.prank(operator1);
        uint256 amount = conduit.withdraw(ilk1, address(asset1), 200);

        assertEq(amount, 100);  // Receive max, which is 100

        assertEq(asset1.balanceOf(address(conduit)), 0);
        assertEq(asset1.balanceOf(buffer1),          100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       100);
        assertEq(conduit.totalWithdrawals(address(asset1)),        100);
    }

    function test_withdraw_singleIlk() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        asset1.mint(address(conduit), 100);

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset1.balanceOf(buffer1),          0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  100);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       0);
        assertEq(conduit.totalWithdrawals(address(asset1)),        0);

        vm.prank(operator1);
        uint256 amount = conduit.withdraw(ilk1, address(asset1), 100);

        assertEq(amount, 100);

        assertEq(asset1.balanceOf(address(conduit)), 0);
        assertEq(asset1.balanceOf(buffer1),          100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       100);
        assertEq(conduit.totalWithdrawals(address(asset1)),        100);
    }

    function test_withdraw_multiIlk_over_under_partial_full_full() external {
        _depositAndDrawFunds(100);
        _depositAndDrawFunds(asset1, operator2, buffer2, broker1, ilk2, 400);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        vm.prank(operator2);
        conduit.requestFunds(ilk2, address(asset1), 400, "info");

        asset1.mint(address(conduit), 500);

        vm.startPrank(arranger);

        conduit.returnFunds(0, 200);  // Over by 100
        conduit.returnFunds(1, 300);  // Under by 100

        vm.stopPrank();

        assertEq(asset1.balanceOf(address(conduit)), 500);
        assertEq(asset1.balanceOf(buffer1),          0);
        assertEq(asset1.balanceOf(buffer2),          0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 200);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  500);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       0);
        assertEq(conduit.withdrawals(address(asset1), ilk2),       0);
        assertEq(conduit.totalWithdrawals(address(asset1)),        0);

        // Partial withdraw ilk1 1

        vm.prank(operator1);
        uint256 amount = conduit.withdraw(ilk1, address(asset1), 50);

        assertEq(amount, 50);

        assertEq(asset1.balanceOf(address(conduit)), 450);
        assertEq(asset1.balanceOf(buffer1),          50);
        assertEq(asset1.balanceOf(buffer2),          0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 150);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  450);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       50);
        assertEq(conduit.withdrawals(address(asset1), ilk2),       0);
        assertEq(conduit.totalWithdrawals(address(asset1)),        50);

        // Finish withdraw ilk1 1

        vm.prank(operator1);
        amount = conduit.withdraw(ilk1, address(asset1), 150);

        assertEq(amount, 150);

        assertEq(asset1.balanceOf(address(conduit)), 300);
        assertEq(asset1.balanceOf(buffer1),          200);
        assertEq(asset1.balanceOf(buffer2),          0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 300);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  300);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       200);
        assertEq(conduit.withdrawals(address(asset1), ilk2),       0);
        assertEq(conduit.totalWithdrawals(address(asset1)),        200);

        // Full withdraw ilk1 2

        vm.prank(operator2);
        amount = conduit.withdraw(ilk2, address(asset1), 300);

        assertEq(amount, 300);

        assertEq(asset1.balanceOf(address(conduit)), 0);
        assertEq(asset1.balanceOf(buffer1),          200);
        assertEq(asset1.balanceOf(buffer2),          300);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);
        assertEq(conduit.withdrawals(address(asset1), ilk1),       200);
        assertEq(conduit.withdrawals(address(asset1), ilk2),       300);
        assertEq(conduit.totalWithdrawals(address(asset1)),        500);
    }

}
