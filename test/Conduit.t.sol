// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IConduit } from "../src/IConduit.sol";

import { Conduit } from "../src/Conduit.sol";

contract ConduitTestBase is Test {

    address admin       = makeAddr("admin");
    address fundManager = makeAddr("fundManager");

    Conduit conduit;

    function setUp() public {
        conduit = new Conduit(fundManager, fundSource);
    }

}
