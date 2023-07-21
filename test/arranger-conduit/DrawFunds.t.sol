// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_drawFundsTests is ConduitAssetTestBase {

    function setUp() public virtual override {
        super.setUp();

        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);
    }

    function test_drawFunds_notArranger() external {
        vm.expectRevert("ArrangerConduit/not-arranger");
        conduit.drawFunds(address(asset), 100);
    }

    function test_drawFunds_insufficientDrawableBoundary() external {
        assertEq(conduit.drawableFunds(address(asset)), 100);

        vm.startPrank(arranger);

        vm.expectRevert("ArrangerConduit/insufficient-funds");
        conduit.drawFunds(address(asset), 101);

        conduit.drawFunds(address(asset), 100);
    }

    function test_drawFunds() public {
        assertEq(conduit.drawableFunds(address(asset)), 100);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 40);

        assertEq(conduit.drawableFunds(address(asset)), 60);

        _assertInvariants(ilk, address(asset));
    }
}
