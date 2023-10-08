// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

contract ArrangerConduit_DrawFundsTests is ConduitAssetTestBase {

    function setUp() public virtual override {
        super.setUp();

        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        asset1.approve(address(conduit), 100);
        conduit.deposit(ilk1, address(asset1), 100);

        vm.stopPrank();
    }

    function test_drawFunds_notArranger() external {
        vm.expectRevert("ArrangerConduit/not-arranger");
        conduit.drawFunds(address(asset1), broker1, 100);
    }

    function test_drawFunds_invalidBroker() external {
        vm.startPrank(arranger);

        vm.expectRevert("ArrangerConduit/invalid-broker");
        conduit.drawFunds(address(asset1), makeAddr("non-broker1"), 100);
    }

    function test_drawFunds_insufficientDrawableBoundary() external {
        assertEq(conduit.availableFunds(address(asset1)), 100);

        vm.startPrank(arranger);

        vm.expectRevert("ArrangerConduit/insufficient-funds");
        conduit.drawFunds(address(asset1), broker1, 101);

        conduit.drawFunds(address(asset1), broker1, 100);
    }

    function test_drawFunds() public {
        assertEq(conduit.availableFunds(address(asset1)), 100);

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset1.balanceOf(broker1),          0);

        vm.prank(arranger);
        conduit.drawFunds(address(asset1), broker1, 40);

        assertEq(conduit.availableFunds(address(asset1)), 60);

        assertEq(asset1.balanceOf(address(conduit)), 60);
        assertEq(asset1.balanceOf(broker1),          40);

        _assertInvariants();
    }
}
