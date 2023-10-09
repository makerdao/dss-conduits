// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import "./ConduitTestBase.sol";

contract ArrangerConduit_RequestFundsTests is ConduitAssetTestBase {

    function test_requestFunds_noIlkAuth() public {
        asset1.mint(buffer1, 100);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 100);

        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.requestFunds(ilk1, address(asset1), 100, "info");
    }

    function test_requestFunds_singleIlk_singleRequest() public {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);

        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        _assertInvariants();
    }

    function test_requestFunds_multiIlk_singleRequest_singleAsset() public {
        asset1.mint(buffer1, 40);
        asset1.mint(buffer2, 60);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 40);

        vm.prank(operator2);
        conduit.deposit(ilk2, address(asset1), 60);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);

        vm.prank(operator1);
        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, "info1");

        assertEq(returnFundRequestId, 0);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info1");

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  40);

        vm.prank(operator2);
        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, "info2");

        assertEq(returnFundRequestId, 1);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk2);
        assertEq(fundRequest.amountRequested, 60);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info2");

        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        _assertInvariants();
    }

    // NOTE: Removing all struct-level assertions for below tests since they have been adequately
    //       asserted in above tests and FundRequest structs are mutually exclusive to each other
    //       as proven in the above test. Below tests are only testing the mapping-level handling of
    //       multi-ilk multi-asset scenarios.

    function test_requestFunds_singleIlk_multiRequest_singleAsset() public {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, "info");

        assertEq(returnFundRequestId, 0);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  40);

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 60, "info");

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        _assertInvariants();
    }

    function test_requestFunds_singleIlk_singleRequest_multiAsset() public {
        asset1.mint(buffer1, 100);
        asset2.mint(buffer1, 300);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);
        conduit.deposit(ilk1, address(asset2), 300);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 100, "info1");

        assertEq(returnFundRequestId, 0);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);
        assertEq(conduit.totalRequestedFunds(address(asset2)),  0);

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 300, "info2");

        assertEq(returnFundRequestId, 1);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 300);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);
        assertEq(conduit.totalRequestedFunds(address(asset2)),  300);

        _assertInvariants();
    }

    function test_requestFunds_multiIlk_multiRequest_multiAsset() public {

        /********************************************/
        /*** First round of deposits and requests ***/
        /********************************************/

        asset1.mint(buffer1, 40);
        asset1.mint(buffer2, 60);
        asset2.mint(buffer1, 100);
        asset2.mint(buffer2, 300);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk1, address(asset2), 100);

        vm.stopPrank();

        vm.startPrank(operator2);

        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk2, address(asset2), 300);

        vm.stopPrank();

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        _assertInvariants();

        // Request Funds for asset1 ilk1

        vm.prank(operator1);
        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, "info");

        assertEq(returnFundRequestId, 0);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        _assertInvariants();

        // Request Funds for asset1 ilk2

        vm.prank(operator2);
        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, "info");

        assertEq(returnFundRequestId, 1);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        _assertInvariants();

        // Request Funds for asset2 ilk1

        vm.prank(operator1);
        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 100, "info");

        assertEq(returnFundRequestId, 2);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 100);

        _assertInvariants();

        // Request Funds for asset2 ilk2

        vm.prank(operator2);
        returnFundRequestId = conduit.requestFunds(ilk2, address(asset2), 300, "info");

        assertEq(returnFundRequestId, 3);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        _assertInvariants();

        /*********************************************/
        /*** Second round of deposits and requests ***/
        /*********************************************/

        asset1.mint(buffer1, 40);
        asset1.mint(buffer2, 60);
        asset2.mint(buffer1, 100);
        asset2.mint(buffer2, 300);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk1, address(asset2), 100);

        vm.startPrank(operator2);

        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk2, address(asset2), 300);

        vm.stopPrank();

        // Request Funds for asset1 ilk1

        vm.prank(operator1);
        returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, "info");

        assertEq(returnFundRequestId, 4);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 80);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 140);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        _assertInvariants();

        // Request Funds for asset1 ilk2

        vm.prank(operator2);
        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, "info");

        assertEq(returnFundRequestId, 5);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 80);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 120);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 200);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        _assertInvariants();

        // Request Funds for asset2 ilk1

        vm.prank(operator1);
        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 100, "info");

        assertEq(returnFundRequestId, 6);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 80);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 120);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 200);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 200);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 500);

        _assertInvariants();

        // Request Funds for asset2 ilk2

        vm.prank(operator2);
        returnFundRequestId = conduit.requestFunds(ilk2, address(asset2), 300, "info");

        assertEq(returnFundRequestId, 7);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 80);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 120);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 200);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 600);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 200);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 800);

        _assertInvariants();
    }

}
