// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_ReturnFundsTest is ConduitAssetTestBase {

    function test_returnFunds_notFundManager() external {
        vm.expectRevert("Conduit/not-fund-manager");
        conduit.returnFunds(address(0), 0);
    }

    function test_returnFunds_noRequests() external {
        vm.startPrank(fundManager);

        asset.mint(address(conduit), 100);

        conduit.drawFunds(address(asset), 100);

        asset.approve(address(conduit), 100);

        assertEq(asset.balanceOf(fundManager),      100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset)),      100);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);

        conduit.returnFunds(address(asset), 100);

        assertEq(asset.balanceOf(fundManager),      0);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.outstandingPrincipal(address(asset)),      0);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);  // No requests, can draw funds again
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);

        conduit.drawFunds(address(asset), 100);  // Draw funds to demonstrate
    }

    function test_returnFunds_oneRequest_complete() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.startPrank(fundManager);

        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        asset.approve(address(conduit), 100);

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountAvailable,
            uint256 amountRequested,
            uint256 amountFilled,
            uint256 fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(asset.balanceOf(fundManager),      100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset)),      100);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);

        conduit.returnFunds(address(asset), 100);

        (
            status,
            actualIlk,
            amountAvailable,
            amountRequested,
            amountFilled,
            fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 100);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(asset.balanceOf(fundManager),      0);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.outstandingPrincipal(address(asset)),      0);
        assertEq(conduit.totalWithdrawable(address(asset)),         100);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 100);
        assertEq(conduit.startingFundRequestId(address(asset)),     1);
    }

    function test_returnFunds_oneRequest_partial() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.startPrank(fundManager);

        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        asset.approve(address(conduit), 100);

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountAvailable,
            uint256 amountRequested,
            uint256 amountFilled,
            uint256 fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(asset.balanceOf(fundManager),      100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset)),      100);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);

        conduit.returnFunds(address(asset), 40);

        (
            status,
            actualIlk,
            amountAvailable,
            amountRequested,
            amountFilled,
            fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 40);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(asset.balanceOf(fundManager),      60);
        assertEq(asset.balanceOf(address(conduit)), 40);

        assertEq(conduit.outstandingPrincipal(address(asset)),      60);
        assertEq(conduit.totalWithdrawable(address(asset)),         40);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 40);
        assertEq(conduit.startingFundRequestId(address(asset)),     1);
    }

}
