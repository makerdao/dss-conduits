// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract OperatorBase is HandlerBase, Test {

    bytes32 ilk;

    constructor(address arrangerConduit_, bytes32 ilk_, address testContract_)
        HandlerBase(arrangerConduit_, testContract_)
    {
        ilk = ilk_;
    }

    function cancelFundRequest(uint256 indexSeed) public virtual {
        uint256 fundRequestId = indexSeed % arrangerConduit.getFundRequestsLength();

        arrangerConduit.cancelFundRequest(fundRequestId);
    }

    function deposit(uint256 indexSeed, uint256 amount) public virtual {
        address asset = _getAsset(indexSeed);

        arrangerConduit.deposit(ilk , asset, amount);
    }

    function requestFunds(uint256 indexSeed, uint256 amount, string memory info) public virtual {
        address asset = _getAsset(indexSeed);

        arrangerConduit.requestFunds(ilk, asset, amount, info);
    }

    function withdraw(uint256 indexSeed, uint256 amount) public virtual {
        address asset = _getAsset(indexSeed);

        arrangerConduit.withdraw(ilk, asset, amount);
    }

}

contract OperatorBounded is OperatorBase {

    constructor(address arrangerConduit_, bytes32 ilk_, address testContract_)
        OperatorBase(arrangerConduit_, ilk_, testContract_) {}

    function cancelFundRequest(uint256 indexSeed) public virtual override {
        uint256[] memory activeFundRequestIds = _getActiveFundRequestIdsForIlk(ilk);

        if (activeFundRequestIds.length == 0) return;

        uint256 fundRequestId = activeFundRequestIds[indexSeed % activeFundRequestIds.length];

        // NOTE: Not using super because id is obtained differently
        arrangerConduit.cancelFundRequest(fundRequestId);
    }

    function deposit(uint256 indexSeed, uint256 amount) public virtual override {
        amount = _bound(amount, 0, 1e45);

        address asset = _getAsset(indexSeed);

        MockERC20(asset).mint(address(this), amount);
        MockERC20(asset).approve(address(arrangerConduit), amount);

        super.deposit(indexSeed, amount);
    }

    function requestFunds(uint256 indexSeed, uint256 amount, string memory info)
        public virtual override
    {
        amount = _bound(amount, 0, 1e45);

        super.requestFunds(indexSeed, amount, info);
    }

    function withdraw(uint256 indexSeed, uint256 amount) public virtual override {
        address asset = _getAsset(indexSeed);

        amount = _bound(amount, 0, arrangerConduit.withdrawableFunds(asset, ilk));

        super.withdraw(indexSeed, amount);
    }

}
