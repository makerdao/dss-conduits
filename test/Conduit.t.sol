// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Test } from "../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IConduit } from "../src/IConduit.sol";
import { Conduit }  from "../src/Conduit.sol";

contract ConduitTestBase is Test {

    address admin       = makeAddr("admin");
    address fundManager = makeAddr("fundManager");

    Conduit conduit;

    function setUp() public virtual {
        conduit = new Conduit(admin, fundManager);
    }

}

contract Conduit_ConstructorTest is ConduitTestBase {

    function test_constructor() public {
        assertEq(conduit.admin(),       admin);
        assertEq(conduit.fundManager(), fundManager);
    }
}

contract Conduit_SetIsValidRouterTest is ConduitTestBase {

    function test_setIsValidRouter_notAdmin() public {
        vm.expectRevert("Conduit/not-admin");
        conduit.setIsValidRouter(address(1), true);
    }

    function test_setIsValidRouter() public {
        vm.startPrank(admin);

        assertTrue(!conduit.isValidRouter(address(1)));

        conduit.setIsValidRouter(address(1), true);
        assertTrue(conduit.isValidRouter(address(1)));

        conduit.setIsValidRouter(address(1), false);
        assertTrue(!conduit.isValidRouter(address(1)));
    }

}

contract Conduit_SetRouterOwnerTest is ConduitTestBase {

    function test_setRouterOwner_notAdmin() public {
        vm.expectRevert("Conduit/not-admin");
        conduit.setRouterOwner(address(1), "SUBDAO_ONE");
    }

    function test_setRouterOwner_notValidRouter() public {
        vm.startPrank(admin);

        vm.expectRevert("Conduit/not-router");
        conduit.setRouterOwner(address(1), "SUBDAO_ONE");
    }

    function test_setRouterOwner() public {
        vm.startPrank(admin);

        address router = makeAddr("router");

        conduit.setIsValidRouter(router, true);

        assertEq(conduit.routerOwner(router), bytes32(0));

        conduit.setRouterOwner(router, "SUBDAO_ONE");
        assertEq(conduit.routerOwner(router), "SUBDAO_ONE");

        conduit.setRouterOwner(router, "SUBDAO_TWO");
        assertEq(conduit.routerOwner(router), "SUBDAO_TWO");
    }

}
