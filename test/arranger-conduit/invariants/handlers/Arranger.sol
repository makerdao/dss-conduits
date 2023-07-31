// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "../../../../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../../../../lib/mock-erc20/src/MockERC20.sol";

import { ArrangerConduit, HandlerBase } from "./HandlerBase.sol";

contract ArrangerHandlerBase is HandlerBase, Test {

    constructor(address arrangerConduit_, address testContract_)
        HandlerBase(arrangerConduit_, testContract_) {}

    function drawFunds(uint256 indexSeed, uint256 amount) public virtual {
        address asset  = _getAsset(indexSeed);
        address broker = _getBroker(indexSeed);

        arrangerConduit.drawFunds(asset, broker, amount);
    }

    function returnFunds(uint256 indexSeed, uint256 amount) public virtual {
        uint256 length = arrangerConduit.getFundRequestsLength();

        uint256 fundRequestId = indexSeed % length;

        arrangerConduit.returnFunds(fundRequestId, amount);
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

        if (!active) return;

        ArrangerConduit.FundRequest memory fundRequest
            = arrangerConduit.getFundRequest(fundRequestId);

        amount = _bound(amount, 0, arrangerConduit.availableFunds(fundRequest.asset));

        arrangerConduit.returnFunds(fundRequestId, amount);
    }

}
