// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";
import { stdError }            from "../lib/forge-std/src/StdError.sol";
import { Test }                from "../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";
import { ArrangerConduit }  from "../src/ArrangerConduit.sol";

contract ConduitTestBase is Test {

    address admin       = makeAddr("admin");
    address fundManager = makeAddr("fundManager");

    ArrangerConduit conduit;

    function setUp() public virtual {
        conduit = new ArrangerConduit(admin, fundManager);
    }

}

contract ConduitAssetTestBase is ConduitTestBase {

    bytes32 ilk = "ilk";

    MockERC20 asset;

    function setUp() public override {
        super.setUp();
        asset = new MockERC20("asset", "ASSET", 18);
    }

}
