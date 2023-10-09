// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import "./ConduitTestBase.sol";

contract ArrangerConduit_CancelFundRequestFailureTests is ConduitAssetTestBase {

    function test_cancelFundRequest_noIlkAuth() public {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        vm.stopPrank();

        vm.prank(arranger);
        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.cancelFundRequest(0);
    }

    function test_cancelFundRequest_notInitialized() public {
        asset1.mint(buffer1, 100);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 100);

        vm.prank(arranger);
        vm.expectRevert(stdError.indexOOBError);
        conduit.cancelFundRequest(0);
    }

    function test_cancelFundRequest_completed() public {
        asset1.mint(buffer1, 100);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 100);

        vm.prank(arranger);
        conduit.drawFunds(address(asset1), broker1, 100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        vm.prank(broker1);
        asset1.transfer(address(conduit), 100);

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        vm.prank(operator1);
        vm.expectRevert("ArrangerConduit/invalid-status");
        conduit.cancelFundRequest(0);
    }

    function test_cancelFundRequest_cancelled() public {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");
        conduit.cancelFundRequest(0);

        vm.expectRevert("ArrangerConduit/invalid-status");
        conduit.cancelFundRequest(0);
    }

}

contract ArrangerConduit_CancelFundRequestTests is ConduitAssetTestBase {

    function test_cancelFundRequest() public {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);

        _assertInvariants();

        conduit.cancelFundRequest(0);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  0);

        _assertInvariants();
    }

}
