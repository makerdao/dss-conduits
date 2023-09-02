// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "../../../../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../../../../lib/mock-erc20/src/MockERC20.sol";

import { ArrangerConduit, HandlerBase } from "./HandlerBase.sol";

contract ArrangerHandlerBase is HandlerBase, Test {

    mapping(address => uint256) public drawnFunds;     // Ghost variable for drawn funds
    mapping(address => uint256) public returnedFunds;  // Ghost variable for returned funds

    constructor(address arrangerConduit_, address testContract_)
        HandlerBase(arrangerConduit_, testContract_) {}

    function drawFunds(uint256 indexSeed, uint256 amount) public virtual {
        address asset  = _getAsset(indexSeed);
        address broker = _getBroker(indexSeed);

        arrangerConduit.drawFunds(asset, broker, amount);

        drawnFunds[asset] += amount;
    }

    function returnFunds(uint256 indexSeed, uint256 amount) public virtual {
        uint256 length = arrangerConduit.getFundRequestsLength();

        uint256 fundRequestId = indexSeed % length;

        console.log("id2", fundRequestId);

        arrangerConduit.returnFunds(fundRequestId, amount);

        returnedFunds[arrangerConduit.getFundRequest(fundRequestId).asset] += amount;
    }

}

contract ArrangerHandlerBoundedBase is ArrangerHandlerBase {

    constructor(address arrangerConduit_, address testContract_)
        ArrangerHandlerBase(arrangerConduit_, testContract_) {}

    function drawFunds(uint256 indexSeed, uint256 amount) public virtual override {
        address asset = _getAsset(indexSeed);
        amount = _bound(amount, 0, arrangerConduit.availableFunds(asset));
        super.drawFunds(indexSeed, amount);
    }

    function returnFunds(uint256 indexSeed, uint256 amount) public virtual override {
        if (arrangerConduit.getFundRequestsLength() == 0) return;

        ( bool active, uint256 fundRequestId ) = _getActiveFundRequestId(indexSeed);

        console2.log("active", active);

        if (!active) return;

        ArrangerConduit.FundRequest memory fundRequest
            = arrangerConduit.getFundRequest(fundRequestId);

        console2.log("fundRequest.amountRequested", fundRequest.amountRequested);

        amount = _bound(amount, 0, fundRequest.amountRequested * 2);

        MockERC20(fundRequest.asset).mint(address(arrangerConduit), amount);

        console2.log("id1", fundRequestId);
        console2.log("available", arrangerConduit.availableFunds(fundRequest.asset));

        super.returnFunds(indexSeed, amount);
    }

}
