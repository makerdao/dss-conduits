// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_RequestFundsFailureTests is ConduitAssetTestBase {

    function test_cancelFundRequest_no_ilkAuth() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.prank(arranger);
        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.cancelFundRequest(0);
    }

    function test_cancelFundRequest_not_initialized() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.prank(arranger);
        vm.expectRevert(stdError.indexOOBError);
        conduit.cancelFundRequest(0);
    }

    function test_cancelFundRequest_completed() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 100);
        conduit.returnFunds(0, 100);

        vm.stopPrank();

        vm.expectRevert("ArrangerConduit/invalid-status");
        conduit.cancelFundRequest(0);
    }

    function test_cancelFundRequest_cancelled() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        conduit.cancelFundRequest(0);

        vm.expectRevert("ArrangerConduit/invalid-status");
        conduit.cancelFundRequest(0);
    }

}

contract Conduit_RequestFundsTests is ConduitAssetTestBase {

    function test_cancelFundRequest() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        (
            IArrangerConduit.StatusEnum status,
            address actualAsset,
            bytes32 actualIlk,
            uint256 amountRequested,
            uint256 amountFilled,
            string memory info
        ) = conduit.fundRequests(0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualAsset,     address(asset));
        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(info,            "info");

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        _assertInvariants(ilk, address(asset));

        conduit.cancelFundRequest(0);

        ( status, actualAsset, actualIlk, amountRequested, amountFilled, info )
            = conduit.fundRequests(0);

        assertTrue(status == IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(actualAsset,     address(asset));
        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(info,            "info");

        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset)), 0);

        _assertInvariants(ilk, address(asset));
    }

}
