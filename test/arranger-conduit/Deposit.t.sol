// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

contract ArrangerConduit_DepositFailureTests is ConduitAssetTestBase {

    function test_deposit_noIlkAuth() public {
        asset.mint(operator, 100);

        asset.approve(address(conduit), 100);

        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.deposit(ilk, address(asset), 100);
    }

    function test_deposit_insufficientApproveBoundary() public {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 99);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), 100);

        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);
    }

    function testFuzz_deposit_insufficientApproveBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset.mint(operator, amount);

        vm.startPrank(operator);

        asset.approve(address(conduit), amount - 1);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), amount);

        asset.approve(address(conduit), amount);

        conduit.deposit(ilk, address(asset), amount);
    }

    function test_deposit_insufficientFundsBoundary() public {
        asset.mint(operator, 99);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), 100);

        asset.mint(operator, 1);

        conduit.deposit(ilk, address(asset), 100);
    }

    function testFuzz_deposit_insufficientFundsBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset.mint(operator, amount - 1);

        vm.startPrank(operator);

        asset.approve(address(conduit), amount);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), amount);

        asset.mint(operator, 1);

        conduit.deposit(ilk, address(asset), amount);
    }

    function test_deposit_noBufferRegistered() external {
        asset.mint(operator, 100);

        registry.file(ilk, "buffer", address(0));

        vm.startPrank(operator);
        asset.approve(address(conduit), 100);

        vm.expectRevert("ArrangerConduit/no-buffer-registered");
        conduit.deposit(ilk, address(asset), 100);

        vm.stopPrank();

        registry.file(ilk, "buffer", operator);

        vm.prank(operator);
        conduit.deposit(ilk, address(asset), 100);
    }

}

contract ArrangerConduit_DepositTests is ConduitAssetTestBase {

    function test_deposit_singleIlk() external {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);

        assertEq(asset.balanceOf(operator),         100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.deposits(address(asset), ilk), 0);
        assertEq(conduit.totalDeposits(address(asset)), 0);

        conduit.deposit(ilk, address(asset), 100);

        assertEq(asset.balanceOf(operator),         0);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.deposits(address(asset), ilk), 100);
        assertEq(conduit.totalDeposits(address(asset)), 100);

        _assertInvariants(ilk, address(asset));
    }

    function testFuzz_deposit_singleIlk(uint256 amount) external {
        asset.mint(operator, amount);

        vm.startPrank(operator);

        asset.approve(address(conduit), amount);

        assertEq(asset.balanceOf(operator),         amount);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.deposits(address(asset), ilk), 0);
        assertEq(conduit.totalDeposits(address(asset)), 0);

        conduit.deposit(ilk, address(asset), amount);

        assertEq(asset.balanceOf(operator),         0);
        assertEq(asset.balanceOf(address(conduit)), amount);

        assertEq(conduit.deposits(address(asset), ilk), amount);
        assertEq(conduit.totalDeposits(address(asset)), amount);

        _assertInvariants(ilk, address(asset));
    }

    function test_deposit_multiIlk() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        address operator1 = makeAddr("operator1");
        address operator2 = makeAddr("operator2");

        _setupOperatorRole(ilk1, operator1);
        _setupOperatorRole(ilk2, operator2);

        registry.file(ilk1, "buffer", operator1);
        registry.file(ilk2, "buffer", operator2);

        asset.mint(operator1, 100);
        asset.mint(operator2, 300);

        assertEq(asset.balanceOf(operator1),        100);
        assertEq(asset.balanceOf(operator2),        300);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.deposits(address(asset), ilk1), 0);
        assertEq(conduit.deposits(address(asset), ilk2), 0);
        assertEq(conduit.totalDeposits(address(asset)),  0);

        vm.startPrank(operator1);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk1, address(asset), 100);

        vm.stopPrank();

        assertEq(asset.balanceOf(operator1),        0);
        assertEq(asset.balanceOf(operator2),        300);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.deposits(address(asset), ilk1), 100);
        assertEq(conduit.deposits(address(asset), ilk2), 0);
        assertEq(conduit.totalDeposits(address(asset)),  100);

        _assertInvariants(ilk1, ilk2, address(asset));

        vm.startPrank(operator2);

        asset.approve(address(conduit), 300);
        conduit.deposit(ilk2, address(asset), 300);

        vm.stopPrank();

        assertEq(asset.balanceOf(operator1),        0);
        assertEq(asset.balanceOf(operator2),        0);
        assertEq(asset.balanceOf(address(conduit)), 400);

        assertEq(conduit.deposits(address(asset), ilk1), 100);
        assertEq(conduit.deposits(address(asset), ilk2), 300);
        assertEq(conduit.totalDeposits(address(asset)),  400);

        _assertInvariants(ilk1, ilk2, address(asset));
    }

}
