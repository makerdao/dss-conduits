// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";

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
            uint256 amountRequested,
            uint256 amountFilled
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);

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
            amountRequested,
            amountFilled
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    100);

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
            uint256 amountRequested,
            uint256 amountFilled
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);

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
            amountRequested,
            amountFilled
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    40);

        assertEq(asset.balanceOf(fundManager),      60);
        assertEq(asset.balanceOf(address(conduit)), 40);

        assertEq(conduit.outstandingPrincipal(address(asset)),      60);
        assertEq(conduit.totalWithdrawable(address(asset)),         40);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 40);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);
    }

    function test_returnFunds_oneIlk_twoRequests_complete_partial() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.startPrank(fundManager);

        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 20, new bytes(0));
        conduit.requestFunds(ilk, address(asset), 80, new bytes(0));

        asset.approve(address(conduit), 100);

        // Removing "constant" assertions from this test to save space and complexity
        (
            IArrangerConduit.StatusEnum status,
            ,
            uint256 amountRequested,
            uint256 amountFilled
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(amountRequested, 20);
        assertEq(amountFilled,    0);

        ( status, , amountRequested, amountFilled ) = conduit.fundRequests(address(asset), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(amountRequested, 80);
        assertEq(amountFilled,    0);

        assertEq(asset.balanceOf(fundManager),      100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset)),      100);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);

        conduit.returnFunds(address(asset), 60);

        ( status, , amountRequested, amountFilled ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(amountRequested, 20);
        assertEq(amountFilled,    20);

        ( status, , amountRequested, amountFilled ) = conduit.fundRequests(address(asset), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(amountRequested, 80);
        assertEq(amountFilled,    40);

        assertEq(asset.balanceOf(fundManager),      40);
        assertEq(asset.balanceOf(address(conduit)), 60);

        assertEq(conduit.outstandingPrincipal(address(asset)),      40);
        assertEq(conduit.totalWithdrawable(address(asset)),         60);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 60);
        assertEq(conduit.startingFundRequestId(address(asset)),     1);
    }

    function test_returnFunds_twoIlks_twoRequests_complete_partial() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk1, address(asset), 40);
        conduit.deposit(ilk2, address(asset), 60);

        vm.startPrank(fundManager);

        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk1, address(asset), 40, new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 60, new bytes(0));

        asset.approve(address(conduit), 70);

        // Removing "constant" assertions from this test to save space and complexity
        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountRequested,
            uint256 amountFilled
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 40);

        ( status, actualIlk, amountRequested, amountFilled )
            = conduit.fundRequests(address(asset), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(amountRequested, 60);
        assertEq(amountFilled,    0);

        assertEq(asset.balanceOf(fundManager),      100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset)),      100);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.startingFundRequestId(address(asset)),     0);

        conduit.returnFunds(address(asset), 70);

        ( status, , amountRequested, amountFilled ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(amountRequested, 40);
        assertEq(amountFilled,    40);

        ( status, , amountRequested, amountFilled ) = conduit.fundRequests(address(asset), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(amountRequested, 60);
        assertEq(amountFilled,    30);

        assertEq(asset.balanceOf(fundManager),      30);
        assertEq(asset.balanceOf(address(conduit)), 70);

        assertEq(conduit.outstandingPrincipal(address(asset)),       30);
        assertEq(conduit.totalWithdrawable(address(asset)),          70);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset)), 40);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset)), 30);
        assertEq(conduit.startingFundRequestId(address(asset)),      1);
    }

    function test_returnFunds_twoIlks_twoAssets_complete_partial() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        MockERC20 asset1 = new MockERC20("asset1", "asset1", 18);
        MockERC20 asset2 = new MockERC20("asset2", "asset2", 18);

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 400);

        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 400);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk1, address(asset2), 100);
        conduit.deposit(ilk2, address(asset2), 300);

        vm.startPrank(fundManager);

        conduit.drawFunds(address(asset1), 100);
        conduit.drawFunds(address(asset2), 400);

        conduit.requestFunds(ilk1, address(asset1), 40,  new bytes(0));
        conduit.requestFunds(ilk2, address(asset1), 60,  new bytes(0));
        conduit.requestFunds(ilk1, address(asset2), 100, new bytes(0));
        conduit.requestFunds(ilk2, address(asset2), 300, new bytes(0));

        asset1.approve(address(conduit), 70);
        asset2.approve(address(conduit), 150);

        // Removing "constant" assertions from this test to save space and complexity

        /**************************************/
        /*** Before state for all positions ***/
        /**************************************/

        // Ilk 1 asset 1

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountRequested,
            uint256 amountFilled
        ) = conduit.fundRequests(address(asset1), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 40);
        assertEq(amountFilled,    0);

        // Ilk 2 asset 1

        ( status, actualIlk, amountRequested, amountFilled )
            = conduit.fundRequests(address(asset1), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 60);
        assertEq(amountFilled,    0);

        // Asset 1 general

        assertEq(asset1.balanceOf(fundManager),      100);
        assertEq(asset1.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset1)),       100);
        assertEq(conduit.totalWithdrawable(address(asset1)),          0);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset1)), 0);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset1)), 0);
        assertEq(conduit.startingFundRequestId(address(asset1)),      0);

        // Ilk 1 asset 2

        ( status, actualIlk, amountRequested, amountFilled )
            = conduit.fundRequests(address(asset2), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);

        // Ilk 2 asset 2

        ( status, actualIlk, amountRequested, amountFilled )
            = conduit.fundRequests(address(asset2), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 300);
        assertEq(amountFilled,    0);

        // Asset 2 general

        assertEq(asset1.balanceOf(fundManager),      100);
        assertEq(asset1.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset2)),       400);
        assertEq(conduit.totalWithdrawable(address(asset2)),          0);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset2)), 0);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset2)), 0);
        assertEq(conduit.startingFundRequestId(address(asset2)),      0);

        /*******************************/
        /*** Return funds for asset1 ***/
        /*******************************/

        conduit.returnFunds(address(asset1), 70);

        // Ilk 1 asset 1 (fully filled)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset1), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(amountRequested, 40);
        assertEq(amountFilled,    40);

        // Ilk 2 asset 1 (partially filled)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset1), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(amountRequested, 60);
        assertEq(amountFilled,    30);

        // Asset 1 general

        assertEq(asset1.balanceOf(fundManager),      30);
        assertEq(asset1.balanceOf(address(conduit)), 70);

        assertEq(conduit.outstandingPrincipal(address(asset1)),       30);
        assertEq(conduit.totalWithdrawable(address(asset1)),          70);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset1)), 40);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset1)), 30);
        assertEq(conduit.startingFundRequestId(address(asset1)),      1);

        // Ilk 1 asset 2 (no change)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset2), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);

        // Ilk 2 asset 2 (no change)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset2), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(amountRequested, 300);
        assertEq(amountFilled,    0);

        // Asset 2 general

        assertEq(asset2.balanceOf(fundManager),      400);
        assertEq(asset2.balanceOf(address(conduit)), 0);

        assertEq(conduit.outstandingPrincipal(address(asset2)),       400);
        assertEq(conduit.totalWithdrawable(address(asset2)),          0);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset2)), 0);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset2)), 0);
        assertEq(conduit.startingFundRequestId(address(asset2)),      0);

        /*******************************/
        /*** Return funds for asset2 ***/
        /*******************************/

        conduit.returnFunds(address(asset2), 150);

        // Ilk 1 asset 1 (no change)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset1), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(amountRequested, 40);
        assertEq(amountFilled,    40);

        // Ilk 2 asset 1 (no change)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset1), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(amountRequested, 60);
        assertEq(amountFilled,    30);

        // Asset 1 general

        assertEq(asset1.balanceOf(fundManager),      30);
        assertEq(asset1.balanceOf(address(conduit)), 70);

        assertEq(conduit.outstandingPrincipal(address(asset1)),       30);
        assertEq(conduit.totalWithdrawable(address(asset1)),          70);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset1)), 40);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset1)), 30);
        assertEq(conduit.startingFundRequestId(address(asset1)),      1);

        // Ilk 1 asset 2 (fully filled)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset2), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.COMPLETED);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    100);

        // Ilk 2 asset 1 (partially filled)

        ( status, , amountRequested, amountFilled )
            = conduit.fundRequests(address(asset2), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(amountRequested, 300);
        assertEq(amountFilled,    50);

        // Asset 1 general

        assertEq(asset2.balanceOf(fundManager),      250);
        assertEq(asset2.balanceOf(address(conduit)), 150);

        assertEq(conduit.outstandingPrincipal(address(asset2)),       250);
        assertEq(conduit.totalWithdrawable(address(asset2)),          150);
        assertEq(conduit.availableWithdrawals(ilk1, address(asset2)), 100);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset2)), 50);
        assertEq(conduit.startingFundRequestId(address(asset2)),      1);
    }

}
