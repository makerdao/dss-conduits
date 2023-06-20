// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_DepositTest is ConduitAssetTestBase {

    // bytes32 ilk = "ilk";

    // MockERC20 asset;

    // function setUp() public override {
    //     super.setUp();
    //     asset = new MockERC20("asset", "ASSET", 18);
    // }

    function test_deposit_insufficientApproveBoundary() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 99);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), 100);

        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);
    }

    function testFuzz_deposit_insufficientApproveBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset.mint(address(this), amount);
        asset.approve(address(conduit), amount - 1);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), amount);

        asset.approve(address(conduit), amount);

        conduit.deposit(ilk, address(asset), amount);
    }

    function test_deposit_insufficientFundsBoundary() public {
        asset.mint(address(this), 99);
        asset.approve(address(conduit), 100);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), 100);

        asset.mint(address(this), 1);

        conduit.deposit(ilk, address(asset), 100);
    }

    function testFuzz_deposit_insufficientFundsBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset.mint(address(this), amount - 1);
        asset.approve(address(conduit), amount);

        vm.expectRevert(stdError.arithmeticError);
        conduit.deposit(ilk, address(asset), amount);

        asset.mint(address(this), 1);

        conduit.deposit(ilk, address(asset), amount);
    }

    function test_deposit_singleIlk() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        assertEq(asset.balanceOf(address(this)),    100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.positions(ilk, address(asset)), 0);
        assertEq(conduit.totalPositions(address(asset)), 0);

        conduit.deposit(ilk, address(asset), 100);

        assertEq(asset.balanceOf(address(this)),    0);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.positions(ilk, address(asset)), 100);
        assertEq(conduit.totalPositions(address(asset)), 100);
    }

    function testFuzz_deposit_singleIlk(uint256 amount) external {
        asset.mint(address(this), amount);
        asset.approve(address(conduit), amount);

        assertEq(asset.balanceOf(address(this)),    amount);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.positions(ilk, address(asset)), 0);
        assertEq(conduit.totalPositions(address(asset)), 0);

        conduit.deposit(ilk, address(asset), amount);

        assertEq(asset.balanceOf(address(this)),    0);
        assertEq(asset.balanceOf(address(conduit)), amount);

        assertEq(conduit.positions(ilk, address(asset)), amount);
        assertEq(conduit.totalPositions(address(asset)), amount);
    }

    function test_deposit_multiIlk() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        asset.mint(address(this), 400);

        asset.approve(address(conduit), 400);

        assertEq(asset.balanceOf(address(this)),    400);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.positions(ilk1, address(asset)), 0);
        assertEq(conduit.positions(ilk2, address(asset)), 0);
        assertEq(conduit.totalPositions(address(asset)),  0);

        conduit.deposit(ilk1, address(asset), 100);

        assertEq(asset.balanceOf(address(this)),    300);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.positions(ilk1, address(asset)), 100);
        assertEq(conduit.positions(ilk2, address(asset)), 0);
        assertEq(conduit.totalPositions(address(asset)),  100);

        conduit.deposit(ilk2, address(asset), 300);

        assertEq(asset.balanceOf(address(this)),    0);
        assertEq(asset.balanceOf(address(conduit)), 400);

        assertEq(conduit.positions(ilk1, address(asset)), 100);
        assertEq(conduit.positions(ilk2, address(asset)), 300);
        assertEq(conduit.totalPositions(address(asset)),  400);
    }

    // TODO: Fuzz test multiIlk multiAsset

}
