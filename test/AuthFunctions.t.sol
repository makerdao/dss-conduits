// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ConduitTestBase } from "./ConduitTestBase.t.sol";

// TODO: Use makeAddr

contract Conduit_RelyTests is ConduitTestBase {

    function test_rely_no_auth() public {
        vm.expectRevert("UpgradeableProxy/not-authorized");
        vm.prank(address(1));
        conduitProxy.rely(address(2));
    }

    function test_rely_auth() public {
        assertEq(conduitProxy.wards(address(1)),    0);
        assertEq(conduitProxy.wards(address(this)), 1);

        vm.expectRevert("UpgradeableProxy/not-authorized");
        vm.prank(address(1));
        conduitProxy.rely(address(1));

        conduitProxy.rely(address(1));

        assertEq(conduitProxy.wards(address(1)), 1);
    }

}

contract Conduit_DenyTests is ConduitTestBase {

    function test_deny_no_auth() public {
        vm.expectRevert("UpgradeableProxy/not-authorized");
        vm.prank(address(1));
        conduitProxy.deny(address(2));
    }

    function test_deny_auth() public {
        assertEq(conduitProxy.wards(address(this)), 1);

        conduitProxy.rely(address(1));

        assertEq(conduitProxy.wards(address(1)), 1);

        vm.expectRevert("UpgradeableProxy/not-authorized");
        vm.prank(address(2));
        conduitProxy.deny(address(1));

        vm.prank(address(1));
        conduitProxy.deny(address(1));

        assertEq(conduitProxy.wards(address(1)), 0);
    }

}

contract Conduit_SetArrangerTests is ConduitTestBase {

    function test_file_no_auth() public {
        vm.expectRevert("ArrangerConduit/not-authorized");
        vm.prank(address(1));
        conduit.file("arranger", address(2));
    }

    function test_file_auth() public {
        assertEq(conduit.arranger(), arranger);

        conduitProxy.rely(address(1));

        assertEq(conduit.wards(address(1)), 1);

        vm.expectRevert("ArrangerConduit/not-authorized");
        vm.prank(address(2));
        conduit.file("arranger", address(1));

        vm.prank(address(1));
        conduit.file("arranger", address(1));

        assertEq(conduit.arranger(), address(1));
    }

}
