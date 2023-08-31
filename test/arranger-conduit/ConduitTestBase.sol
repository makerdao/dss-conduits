// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "dss-test/DssTest.sol";

import { AllocatorRegistry } from "dss-allocator/AllocatorRegistry.sol";
import { AllocatorRoles }    from "dss-allocator/AllocatorRoles.sol";

import { MockERC20 } from "mock-erc20/MockERC20.sol";

import { UpgradeableProxy } from "upgradeable-proxy/UpgradeableProxy.sol";

import { ArrangerConduit } from "../../src/ArrangerConduit.sol";

// TODO: Add test for deposit and returnFunds without request

contract ConduitTestBase is DssTest {

    address admin    = makeAddr("admin");
    address arranger = makeAddr("arranger");
    address operator = makeAddr("operator");

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

    address broker = makeAddr("broker");

    bytes32 ilk = "ilk";

    MockERC20 asset = new MockERC20("asset", "ASSET", 18);

    function setUp() public virtual override {
        super.setUp();

        _setupOperatorRole(ilk, operator);

        registry.file(ilk, "buffer", operator);

        conduit.setBroker(broker, address(asset), true);
    }

    function _assertInvariants(bytes32 ilk_, address asset_) internal {
        _assertInvariants(ilk_, "", asset_);
    }

    function _assertInvariants(bytes32 ilk1, bytes32 ilk2, address asset_) internal {
        assertEq(
            conduit.totalDeposits(asset_),
            conduit.deposits(ilk1, asset_) + conduit.deposits(ilk2, asset_)
        );

        assertEq(
            conduit.totalRequestedFunds(asset_),
            conduit.requestedFunds(ilk1, asset_) + conduit.requestedFunds(ilk2, asset_)
        );

        assertEq(
            conduit.totalWithdrawableFunds(asset_),
            conduit.withdrawableFunds(ilk1, asset_) + conduit.withdrawableFunds(ilk2, asset_)
        );

        assertEq(
            conduit.totalWithdrawals(asset_),
            conduit.withdrawals(ilk1, asset_) + conduit.withdrawals(ilk2, asset_)
        );
    }

    function _depositAndDrawFunds(
        MockERC20 asset_,
        address   operator_,
        bytes32   ilk_,
        uint256   amount
    )
        internal
    {
        vm.startPrank(operator_);
        asset_.mint(operator_, amount);
        asset_.approve(address(conduit), amount);

        conduit.deposit(ilk_, address(asset_), amount);

        vm.startPrank(arranger);
        conduit.drawFunds(address(asset_), broker, amount);

        vm.stopPrank();
    }

    function _setupOperatorRole(bytes32 ilk_, address operator_) internal {
        // Ensure address(this) can always set for a new ilk
        roles.setIlkAdmin(ilk_, address(this));

        roles.setUserRole(ilk_, operator_, ROLE, true);

        address conduit_ = address(conduit);

        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.deposit.selector,           true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.withdraw.selector,          true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.requestFunds.selector,      true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.cancelFundRequest.selector, true);
    }

}

