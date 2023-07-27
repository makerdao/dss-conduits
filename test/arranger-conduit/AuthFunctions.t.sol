// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

contract ArrangerConduit_AuthTests is ConduitTestBase {

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

    function test_setBroker_noAuth() external {
        vm.prank(makeAddr("non-admin"));
        vm.expectRevert("ArrangerConduit/not-authorized");
        conduit.setBroker(makeAddr("broker"), makeAddr("asset"), true);
    }

    function test_setBroker() external {
        address asset1  = makeAddr("asset1");
        address asset2  = makeAddr("asset2");
        address broker1 = makeAddr("broker1");
        address broker2 = makeAddr("broker2");

        _assertBrokerSetter(broker1, asset1);
        _assertBrokerSetter(broker1, asset2);
        _assertBrokerSetter(broker2, asset1);
        _assertBrokerSetter(broker2, asset2);
    }

    function _assertBrokerSetter(address broker, address asset) internal {
        assertTrue(!conduit.isBroker(broker, asset));

        conduit.setBroker(broker, asset, true);

        assertTrue(conduit.isBroker(broker, asset));

        conduit.setBroker(broker, asset, false);

        assertTrue(!conduit.isBroker(broker, asset));
    }

}
