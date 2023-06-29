// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ConduitTestBase } from "./ConduitTestBase.sol";

contract Conduit_ConstructorTest is ConduitTestBase {

    function test_constructor() public {
        assertEq(conduit.arranger(), arranger);
        assertEq(conduit.roles(),    address(roles));

        assertEq(conduit.wards(address(this)), 1);
    }

}
