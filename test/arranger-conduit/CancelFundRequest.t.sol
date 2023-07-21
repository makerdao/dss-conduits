// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_RequestFundsFailureTests is ConduitAssetTestBase {

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

contract ArrangerConduit_RequestFundsTests is ConduitAssetTestBase {

    function test_cancelFundRequest() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset));
        assertEq(fundRequest.ilk,             ilk);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        _assertInvariants(ilk, address(asset));

        conduit.cancelFundRequest(0);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(fundRequest.asset,           address(asset));
        assertEq(fundRequest.ilk,             ilk);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset)), 0);

        _assertInvariants(ilk, address(asset));
    }

}
