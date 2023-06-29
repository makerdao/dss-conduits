// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { AllocatorRoles } from "../lib/dss-allocator/src/AllocatorRoles.sol";

import { console2 as console } from "../lib/forge-std/src/console2.sol";
import { stdError }            from "../lib/forge-std/src/StdError.sol";
import { Test }                from "../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";
import { ArrangerConduit }  from "../src/ArrangerConduit.sol";

// TODO: Refactor all tests to use different operators and ilk admins

contract ConduitTestBase is Test {

    address admin    = makeAddr("admin");
    address arranger = makeAddr("arranger");

    AllocatorRoles roles = new AllocatorRoles();

    ArrangerConduit conduit;

    function setUp() public virtual {
        conduit = new ArrangerConduit(admin, arranger, address(roles));
    }

}

contract ConduitAssetTestBase is ConduitTestBase {

    uint8 ARRANGER_ROLE = 0;
    uint8 OPERATOR_ROLE = 1;

    bytes32 ilk = "ilk";

    MockERC20 asset;

    function setUp() public override {
        super.setUp();
        asset = new MockERC20("asset", "ASSET", 18);

        _setUpRoles(ilk, arranger, address(this));
    }

    function _assertInvariants(bytes32 ilk_, address asset_) internal {
        _assertInvariants(ilk_, "", asset_);
    }

    function _assertInvariants(bytes32 ilk1, bytes32 ilk2, address asset_) internal {
        uint256 totalSupply = MockERC20(asset_).totalSupply();

        assertEq(
            MockERC20(asset_).balanceOf(address(this))
                + MockERC20(asset_).balanceOf(arranger)
                + MockERC20(asset_).balanceOf(address(conduit)),
            totalSupply
        );

        assertEq(
            conduit.totalWithdrawableFunds(asset_),
            conduit.withdrawableFunds(ilk1, asset_) + conduit.withdrawableFunds(ilk2, asset_)
        );

        assertEq(
            conduit.totalRequestedFunds(asset_),
            conduit.requestedFunds(ilk1, asset_) + conduit.requestedFunds(ilk2, asset_)
        );
    }

    function _depositAndDrawFunds(MockERC20 asset_, bytes32 ilk_, uint256 amount) internal {
        asset_.mint(address(this), amount);
        asset_.approve(address(conduit), amount);

        conduit.deposit(ilk_, address(asset_), amount);

        vm.startPrank(arranger);
        conduit.drawFunds(address(asset_), amount);

        uint256 allowance = asset.allowance(address(this), address(conduit));

        asset_.approve(address(conduit), allowance + amount);

        vm.stopPrank();
    }

    function _setUpRoles(bytes32 ilk_, address arranger_, address operator_) internal {
        roles.setIlkAdmin(ilk_, address(this));
        roles.setUserRole(ilk_, arranger_, ARRANGER_ROLE, true);
        roles.setUserRole(ilk_, operator_, OPERATOR_ROLE, true);

        address conduit_ = address(conduit);

        roles.setRoleAction(ilk, ARRANGER_ROLE, conduit_, conduit.drawFunds.selector,   true);
        roles.setRoleAction(ilk, ARRANGER_ROLE, conduit_, conduit.returnFunds.selector, true);

        roles.setRoleAction(ilk, OPERATOR_ROLE, conduit_, conduit.deposit.selector,           true);
        roles.setRoleAction(ilk, OPERATOR_ROLE, conduit_, conduit.withdraw.selector,          true);
        roles.setRoleAction(ilk, OPERATOR_ROLE, conduit_, conduit.requestFunds.selector,      true);
        roles.setRoleAction(ilk, OPERATOR_ROLE, conduit_, conduit.cancelFundRequest.selector, true);
    }

}
