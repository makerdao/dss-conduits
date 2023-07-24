// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ConduitAssetTestBase } from "./ConduitTestBase.t.sol";
import { RevertingERC20 }       from "./RevertingERC20.sol";

contract ArrangerConduit_drawFundsTests is ConduitAssetTestBase {

    function setUp() public virtual override {
        super.setUp();

        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);

        vm.stopPrank();
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

    function test_drawFunds_transferRevert() external {
        RevertingERC20 erc20 = new RevertingERC20("erc20", "ERC20", 18);

        vm.etch(address(asset), address(erc20).code);

        vm.prank(arranger);
        vm.expectRevert("ArrangerConduit/transfer-failed");
        conduit.drawFunds(address(asset), 100);
    }

    function test_drawFunds() public {
        assertEq(conduit.drawableFunds(address(asset)), 100);

        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(arranger),         0);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 40);

        assertEq(conduit.drawableFunds(address(asset)), 60);

        assertEq(asset.balanceOf(address(conduit)), 60);
        assertEq(asset.balanceOf(arranger),         40);

        _assertInvariants(ilk, address(asset));
    }
}
