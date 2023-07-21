// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { DssTest } from "dss-test/DssTest.sol";

import { ConduitTestBase } from "./ConduitTestBase.t.sol";

// TODO: Use makeAddr

contract ArrangerConduit_AuthTests is DssTest, ConduitTestBase {

    function test_auth() external {
        checkAuth(address(conduitProxy), "UpgradeableProxy");
    }

    function test_modifiers() external {
        bytes4[] memory authedMethods = new bytes4[](1);
        authedMethods[0] = conduitProxy.setImplementation.selector;

        vm.startPrank(makeAddr("non-admin"));
        checkModifier(address(conduitProxy), "UpgradeableProxy/not-authorized", authedMethods);
        vm.stopPrank();
    }

    function test_file() external {
        checkFileAddress(
            address(conduitProxy),
            "ArrangerConduit",
            ["arranger", "registry", "roles"]
        );
    }

    function test_setImplementation() external {
        address newImplementation = makeAddr("new-implementation");

        assertEq(conduitProxy.implementation(), address(conduitImplementation));

        conduitProxy.setImplementation(newImplementation);

        assertEq(conduitProxy.implementation(), newImplementation);
    }

}
