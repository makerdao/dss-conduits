// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { AllocatorRegistry } from "../../lib/dss-allocator/src/AllocatorRegistry.sol";
import { AllocatorRoles }    from "../../lib/dss-allocator/src/AllocatorRoles.sol";

import { console2 as console } from "../../lib/forge-std/src/console2.sol";
import { stdError }            from "../../lib/forge-std/src/StdError.sol";
import { Test }                from "../../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

import { UpgradeableProxy } from "../../lib/upgradeable-proxy/src/UpgradeableProxy.sol";

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";
import { ArrangerConduit }  from "../../src/ArrangerConduit.sol";

// TODO: Refactor all tests to use different operators and ilk admins
// TODO: ilkAuth checks for all relevant functions
// TODO: Failure tests for all relevant functions
// TODO: Assert balance changes in ReturnFunds.t.sol line 213 and wherever else relevant
// TODO: Try out .tree files
// TODO: Add tests for maxWithdraw and gerFundRequestsLength()

contract ConduitTestBase is Test {

    address admin    = makeAddr("admin");
    address arranger = makeAddr("arranger");

    AllocatorRegistry registry = new AllocatorRegistry();
    AllocatorRoles    roles    = new AllocatorRoles();

    ArrangerConduit  conduit;
    ArrangerConduit  conduitImplementation;
    UpgradeableProxy conduitProxy;

    function setUp() public virtual {
        conduitProxy = new UpgradeableProxy();

        conduitImplementation = new ArrangerConduit();

        conduitProxy.setImplementation(address(conduitImplementation));

        conduit = ArrangerConduit(address(conduitProxy));

        conduit.file("arranger", arranger);
        conduit.file("registry", address(registry));
        conduit.file("roles",    address(roles));
    }

}

contract ConduitAssetTestBase is ConduitTestBase {

    uint8 ROLE = 0;

    bytes32 ilk = "ilk";

    MockERC20 asset = new MockERC20("asset", "ASSET", 18);

    function setUp() public virtual override {
        super.setUp();

        _setupRoles(ilk, address(this));

        registry.file(ilk, "buffer", address(this));  // TODO: Use dedicated buffer addresses
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

    function _setupRoles(bytes32 ilk_, address operator_) internal {
        roles.setIlkAdmin(ilk_, address(this));
        roles.setUserRole(ilk_, operator_, ROLE, true);

        address conduit_ = address(conduit);

        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.deposit.selector,           true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.withdraw.selector,          true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.requestFunds.selector,      true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.cancelFundRequest.selector, true);
    }

}

