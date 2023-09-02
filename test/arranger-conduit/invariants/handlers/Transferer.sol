// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract TransfererHandlerBase is HandlerBase, Test {

    constructor(address arrangerConduit_, address testContract_)
        HandlerBase(arrangerConduit_, testContract_) {}

    function transfer(uint256 indexSeed, uint256 amount) public virtual {
        address asset = _getAsset(indexSeed);

        MockERC20(asset).transfer(address(arrangerConduit), amount);
    }

}

contract TransfererHandlerBoundedBase is TransfererHandlerBase {

    constructor(address arrangerConduit_, address testContract_)
        TransfererHandlerBase(arrangerConduit_, testContract_) {}

    function transfer(uint256 indexSeed, uint256 amount) public virtual override {
        address asset = _getAsset(indexSeed);
        amount = _bound(amount, 0, 1e30);

        MockERC20(asset).mint(address(this), amount);

        // NOTE: Have to use indexSeed again so function is overridden
        super.transfer(indexSeed, amount);
    }

}
