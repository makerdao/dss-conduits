// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

contract ArrangerConduit_DepositFailureTests is ConduitAssetTestBase {

    function test_deposit_noIlkAuth() public {
        asset1.mint(buffer1, 100);

        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.deposit(ilk1, address(asset1), 100);
    }

    // NOTE: This test doesn't apply really in practice because of buffer setup, but being thorough
    function test_deposit_insufficientApproveBoundary() public {
        asset1.mint(buffer1, 100);

        vm.prank(buffer1);
        asset1.approve(address(conduit), 99);

        vm.prank(operator1);
        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk1, address(asset1), 100);

        vm.prank(buffer1);
        asset1.approve(address(conduit), 100);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 100);
    }

    // NOTE: This test doesn't apply really in practice because of buffer setup, but being thorough
    function testFuzz_deposit_insufficientApproveBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset1.mint(buffer1, amount);

        vm.prank(buffer1);
        asset1.approve(address(conduit), amount - 1);

        vm.prank(operator1);
        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk1, address(asset1), amount);

        vm.prank(buffer1);
        asset1.approve(address(conduit), amount);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), amount);
    }

    function test_deposit_insufficientFundsBoundary() public {
        asset1.mint(buffer1, 99);

        vm.startPrank(operator1);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk1, address(asset1), 100);

        asset1.mint(buffer1, 1);

        conduit.deposit(ilk1, address(asset1), 100);
    }

    function testFuzz_deposit_insufficientFundsBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset1.mint(buffer1, amount - 1);

        vm.startPrank(operator1);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk1, address(asset1), amount);

        asset1.mint(buffer1, 1);

        conduit.deposit(ilk1, address(asset1), amount);
    }

}

contract ArrangerConduit_DepositTests is ConduitAssetTestBase {

    function test_deposit_singleIlk() external {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        assertEq(asset1.balanceOf(buffer1),          100);
        assertEq(asset1.balanceOf(address(conduit)), 0);

        assertEq(conduit.deposits(address(asset1), ilk1), 0);
        assertEq(conduit.totalDeposits(address(asset1)),  0);

        conduit.deposit(ilk1, address(asset1), 100);

        assertEq(asset1.balanceOf(buffer1),          0);
        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.deposits(address(asset1), ilk1), 100);
        assertEq(conduit.totalDeposits(address(asset1)),  100);

        _assertInvariants();
    }

    function testFuzz_deposit_singleIlk(uint256 amount) external {
        asset1.mint(buffer1, amount);

        vm.startPrank(operator1);

        assertEq(asset1.balanceOf(buffer1),          amount);
        assertEq(asset1.balanceOf(address(conduit)), 0);

        assertEq(conduit.deposits(address(asset1), ilk1), 0);
        assertEq(conduit.totalDeposits(address(asset1)),  0);

        conduit.deposit(ilk1, address(asset1), amount);

        assertEq(asset1.balanceOf(buffer1),          0);
        assertEq(asset1.balanceOf(address(conduit)), amount);

        assertEq(conduit.deposits(address(asset1), ilk1), amount);
        assertEq(conduit.totalDeposits(address(asset1)),  amount);

        _assertInvariants();
    }

    function test_deposit_multiIlk() external {
        asset1.mint(buffer1, 100);
        asset1.mint(buffer2, 300);

        assertEq(asset1.balanceOf(buffer1),          100);
        assertEq(asset1.balanceOf(buffer2),          300);
        assertEq(asset1.balanceOf(address(conduit)), 0);

        assertEq(conduit.deposits(address(asset1), ilk1), 0);
        assertEq(conduit.deposits(address(asset1), ilk2), 0);
        assertEq(conduit.totalDeposits(address(asset1)),  0);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 100);

        assertEq(asset1.balanceOf(buffer1),          0);
        assertEq(asset1.balanceOf(buffer2),          300);
        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.deposits(address(asset1), ilk1), 100);
        assertEq(conduit.deposits(address(asset1), ilk2), 0);
        assertEq(conduit.totalDeposits(address(asset1)),  100);

        _assertInvariants();

        vm.prank(operator2);
        conduit.deposit(ilk2, address(asset1), 300);

        assertEq(asset1.balanceOf(buffer1),          0);
        assertEq(asset1.balanceOf(buffer2),          0);
        assertEq(asset1.balanceOf(address(conduit)), 400);

        assertEq(conduit.deposits(address(asset1), ilk1), 100);
        assertEq(conduit.deposits(address(asset1), ilk2), 300);
        assertEq(conduit.totalDeposits(address(asset1)),  400);

        _assertInvariants();
    }

}
