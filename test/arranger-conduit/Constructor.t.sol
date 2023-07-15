// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ConduitTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_ConstructorTests is ConduitTestBase {

    function test_constructor() public {
        assertEq(conduit.wards(address(this)), 1);
    }

}
