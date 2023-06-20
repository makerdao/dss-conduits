// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";


contract Conduit_ReturnFundsTest is ConduitAssetTestBase {

    function test_withdraw_insufficientAvailableWithdrawalBoundary() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.startPrank(fundManager);
        conduit.drawFunds(address(asset), 100);

        asset.approve(address(conduit), 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        conduit.returnFunds(address(asset), 99);

        vm.expectRevert("Conduit/insufficient-withdrawal");
        conduit.withdraw(ilk, address(asset), address(this), 100);

        conduit.returnFunds(address(asset), 1);

        conduit.withdraw(ilk, address(asset), address(this), 100);
    }

    // TODO: Determine if failure from insufficient balance is possible

    function _depositAndDrawFunds(MockERC20 asset_, bytes32 ilk_, uint256 amount) internal {
        asset_.mint(address(this), amount);
        asset_.approve(address(conduit), amount);

        conduit.deposit(ilk_, address(asset_), amount);

        vm.startPrank(fundManager);
        conduit.drawFunds(address(asset_), amount);

        uint256 allowance = asset.allowance(address(this), address(conduit));

        asset_.approve(address(conduit), allowance + amount);

        vm.stopPrank();
    }

    function test_withdraw_oneRequest_complete() external {
        _depositAndDrawFunds(asset, ilk, 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        vm.prank(fundManager);
        conduit.returnFunds(address(asset), 100);

        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(address(this)),    0);

        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 100);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)),   100);
        assertEq(conduit.positions(ilk, address(asset)),            100);
        assertEq(conduit.totalPositions(address(asset)),            100);
        assertEq(conduit.totalWithdrawable(address(asset)),         100);

        conduit.withdraw(ilk, address(asset), address(this), 100);

        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(address(this)),    100);

        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)),   0);
        assertEq(conduit.positions(ilk, address(asset)),            0);
        assertEq(conduit.totalPositions(address(asset)),            0);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
    }

    function test_withdraw_twoRequests_complete_partial() external {
        _depositAndDrawFunds(asset, ilk, 100);

        conduit.requestFunds(ilk, address(asset), 40, new bytes(0));
        conduit.requestFunds(ilk, address(asset), 60, new bytes(0));

        vm.prank(fundManager);
        conduit.returnFunds(address(asset), 70);

        assertEq(asset.balanceOf(fundManager),      30);
        assertEq(asset.balanceOf(address(conduit)), 70);
        assertEq(asset.balanceOf(address(this)),    0);

        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 70);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)),   100);
        assertEq(conduit.positions(ilk, address(asset)),            100);
        assertEq(conduit.totalPositions(address(asset)),            100);
        assertEq(conduit.totalWithdrawable(address(asset)),         70);

        // TODO: Investigate partial withdrawals
        conduit.withdraw(ilk, address(asset), address(this), 70);

        assertEq(asset.balanceOf(fundManager),      30);
        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(address(this)),    70);

        assertEq(conduit.availableWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)),   30);
        assertEq(conduit.positions(ilk, address(asset)),            30);
        assertEq(conduit.totalPositions(address(asset)),            30);
        assertEq(conduit.totalWithdrawable(address(asset)),         0);
    }

    function test_withdraw_twoIlks_complete_complete_complete_partial() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        address dest1 = makeAddr("destination1");
        address dest2 = makeAddr("destination2");

        _depositAndDrawFunds(asset, ilk1, 100);
        _depositAndDrawFunds(asset, ilk2, 400);

        conduit.requestFunds(ilk1, address(asset), 40,  new bytes(0));
        conduit.requestFunds(ilk1, address(asset), 60,  new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 100, new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 300, new bytes(0));

        vm.prank(fundManager);
        conduit.returnFunds(address(asset), 310);

        assertEq(asset.balanceOf(fundManager),      190);
        assertEq(asset.balanceOf(address(conduit)), 310);
        assertEq(asset.balanceOf(dest1),            0);

        assertEq(conduit.availableWithdrawals(ilk1, address(asset)), 100);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset)), 210);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)),   100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)),   400);
        assertEq(conduit.positions(ilk1, address(asset)),            100);
        assertEq(conduit.positions(ilk2, address(asset)),            400);
        assertEq(conduit.totalPositions(address(asset)),             500);
        assertEq(conduit.totalWithdrawable(address(asset)),          310);

        // Demonstrate that withdrawal order is dependent on the order in which the requests are
        // made, not the order of actioned withdrawals. There is enough funds to fulfill ilk2's
        // withdrawal of 211 (300 balance and 300 pending withdraw), but since 100 is earmarked for
        // ilk1, ilk2 can only withdraw a max of 190.
        vm.expectRevert("Conduit/insufficient-withdrawal");
        conduit.withdraw(ilk2, address(asset), dest2, 211);

        conduit.withdraw(ilk2, address(asset), dest2, 210);

        assertEq(asset.balanceOf(fundManager),      190);
        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(dest1),            0);
        assertEq(asset.balanceOf(dest2),            210);

        assertEq(conduit.availableWithdrawals(ilk1, address(asset)), 100);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset)), 0);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)),   100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)),   190);
        assertEq(conduit.positions(ilk1, address(asset)),            100);
        assertEq(conduit.positions(ilk2, address(asset)),            190);
        assertEq(conduit.totalPositions(address(asset)),             290);
        assertEq(conduit.totalWithdrawable(address(asset)),          100);

        conduit.withdraw(ilk1, address(asset), dest1, 100);

        assertEq(asset.balanceOf(fundManager),      190);
        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(dest1),            100);
        assertEq(asset.balanceOf(dest2),            210);

        assertEq(conduit.availableWithdrawals(ilk1, address(asset)), 0);
        assertEq(conduit.availableWithdrawals(ilk2, address(asset)), 0);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)),   0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)),   190);
        assertEq(conduit.positions(ilk1, address(asset)),            0);
        assertEq(conduit.positions(ilk2, address(asset)),            190);
        assertEq(conduit.totalPositions(address(asset)),             190);
        assertEq(conduit.totalWithdrawable(address(asset)),          0);
    }

}
