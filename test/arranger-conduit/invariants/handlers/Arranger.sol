// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

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
        // Get a random fundRequestId
        uint256 fundRequestId = indexSeed % arrangerConduit.getFundRequestsLength();

        arrangerConduit.returnFunds(fundRequestId, amount);

        // Add to the returnedFunds ghost var for the fundRequest's asset
        returnedFunds[arrangerConduit.getFundRequest(fundRequestId).asset] += amount;
    }

}

contract ArrangerHandlerBoundedBase is ArrangerHandlerBase {

    constructor(address arrangerConduit_, address testContract_)
        ArrangerHandlerBase(arrangerConduit_, testContract_) {}

    function drawFunds(uint256 indexSeed, uint256 amount) public virtual override {
        // Draw funds for an amount between zero and the full available amount
        amount = _bound(amount, 0, arrangerConduit.availableFunds(_getAsset(indexSeed)));
        super.drawFunds(indexSeed, amount);
    }

    function returnFunds(uint256 indexSeed, uint256 amount) public virtual override {
        if (arrangerConduit.getFundRequestsLength() == 0) return;

        ( bool active, uint256 fundRequestId ) = _getActiveFundRequestId(indexSeed);

        if (!active) return;  // Only returnFunds for active fund requests

        ArrangerConduit.FundRequest memory fundRequest
            = arrangerConduit.getFundRequest(fundRequestId);

        // Get exposure to amounts above and below the requested amount
        amount = _bound(amount, 0, fundRequest.amountRequested * 2);

        MockERC20(fundRequest.asset).mint(address(arrangerConduit), amount);

        // NOTE: Not using `super.returnFunds` because IDs are derived in different ways
        arrangerConduit.returnFunds(fundRequestId, amount);

        returnedFunds[arrangerConduit.getFundRequest(fundRequestId).asset] += amount;
    }

}
