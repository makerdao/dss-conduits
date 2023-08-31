// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ConduitTestBase.sol";

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
        conduit.drawFunds(address(asset), broker, 100);
    }

    function test_drawFunds_invalidBroker() external {
        vm.startPrank(arranger);

        vm.expectRevert("ArrangerConduit/invalid-broker");
        conduit.drawFunds(address(asset), makeAddr("non-broker"), 100);
    }

    function test_drawFunds_insufficientDrawableBoundary() external {
        assertEq(conduit.availableFunds(address(asset)), 100);

        vm.startPrank(arranger);

        vm.expectRevert("ArrangerConduit/insufficient-funds");
        conduit.drawFunds(address(asset), broker, 101);

        conduit.drawFunds(address(asset), broker, 100);
    }

    function test_drawFunds_transferRevert() external {
        vm.mockCall(
            address(asset),
            abi.encodeWithSelector(asset.transfer.selector, broker, 0),
            abi.encode(false)
        );

        vm.prank(arranger);
        vm.expectRevert("SafeERC20/transfer-failed");
        conduit.drawFunds(address(asset), broker, 0);
    }

    function test_drawFunds() public {
        assertEq(conduit.availableFunds(address(asset)), 100);

        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(broker),           0);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), broker, 40);

        assertEq(conduit.availableFunds(address(asset)), 60);

        assertEq(asset.balanceOf(address(conduit)), 60);
        assertEq(asset.balanceOf(broker),           40);

        _assertInvariants(ilk, address(asset));
    }
}
