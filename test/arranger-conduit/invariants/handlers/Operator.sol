// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "../../../../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../../../../lib/mock-erc20/src/MockERC20.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract OperatorHandlerBase is HandlerBase, Test {

    constructor(address arrangerConduit_, address testContract_)
        HandlerBase(arrangerConduit_, testContract_) {}

    function deposit(uint256 indexSeed, uint256 amount) public virtual {
        address asset = _getAsset(indexSeed);
        bytes32 ilk   = _getIlk(indexSeed);

        MockERC20(asset).mint(address(this), amount);
        MockERC20(asset).approve(address(arrangerConduit), amount);

        arrangerConduit.deposit(ilk , asset, amount);
    }

}

contract OperatorHandlerBoundedBase is OperatorHandlerBase {

    constructor(address arrangerConduit_, address testContract_)
        OperatorHandlerBase(arrangerConduit_, testContract_) {}

    function deposit(uint256 indexSeed, uint256 amount) public virtual override {
        amount = _bound(amount, 0, 1e45);
        super.deposit(indexSeed, amount);
    }

}
