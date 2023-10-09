// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "dss-test/DssTest.sol";

import { AllocatorRegistry } from "dss-allocator/AllocatorRegistry.sol";
import { AllocatorRoles }    from "dss-allocator/AllocatorRoles.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { UpgradeableProxy } from "upgradeable-proxy/UpgradeableProxy.sol";

import { ArrangerConduit } from "../../src/ArrangerConduit.sol";

contract ConduitTestBase is DssTest {

    address admin     = makeAddr("admin");
    address arranger  = makeAddr("arranger");
    address buffer1   = makeAddr("buffer1");
    address buffer2   = makeAddr("buffer2");
    address operator1 = makeAddr("operator1");
    address operator2 = makeAddr("operator2");

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

    address broker1 = makeAddr("broker1");
    address broker2 = makeAddr("broker2");

    bytes32 ilk1 = "ilk1";
    bytes32 ilk2 = "ilk2";

    MockERC20 asset1 = new MockERC20("asset1", "ASSET1", 18);
    MockERC20 asset2 = new MockERC20("asset2", "ASSET2", 18);

    function setUp() public virtual override {
        super.setUp();

        _setupOperatorRole(ilk1, operator1);
        _setupOperatorRole(ilk2, operator2);

        registry.file(ilk1, "buffer", buffer1);
        registry.file(ilk2, "buffer", buffer2);

        conduit.setBroker(broker1, address(asset1), true);
        conduit.setBroker(broker2, address(asset2), true);

        vm.startPrank(buffer1);
        asset1.approve(address(conduit), type(uint256).max);
        asset2.approve(address(conduit), type(uint256).max);

        vm.startPrank(buffer2);
        asset1.approve(address(conduit), type(uint256).max);
        asset2.approve(address(conduit), type(uint256).max);

        vm.stopPrank();
    }

    function _assertInvariants() internal {
        _assertInvariants(address(asset1));
        _assertInvariants(address(asset2));
    }

    function _assertInvariants(address asset_) internal {
        assertEq(
            conduit.totalDeposits(asset_),
            conduit.deposits(asset_, ilk1) + conduit.deposits(asset_, ilk2)
        );

        assertEq(
            conduit.totalRequestedFunds(asset_),
            conduit.requestedFunds(asset_, ilk1) + conduit.requestedFunds(asset_, ilk2)
        );

        assertEq(
            conduit.totalWithdrawableFunds(asset_),
            conduit.withdrawableFunds(asset_, ilk1) + conduit.withdrawableFunds(asset_, ilk2)
        );

        assertEq(
            conduit.totalWithdrawals(asset_),
            conduit.withdrawals(asset_, ilk1) + conduit.withdrawals(asset_, ilk2)
        );
    }

    function _depositAndDrawFunds(
        MockERC20 asset_,
        address   operator_,
        address   buffer_,
        address   broker_,
        bytes32   ilk_,
        uint256   amount
    )
        internal
    {
        asset_.mint(buffer_, amount);

        vm.prank(operator_);
        conduit.deposit(ilk_, address(asset_), amount);

        vm.prank(arranger);
        conduit.drawFunds(address(asset_), broker_, amount);
    }

    // NOTE: Majority of tests use these params
    function _depositAndDrawFunds(uint256 amount) internal {
        _depositAndDrawFunds(asset1, operator1, buffer1, broker1, ilk1, amount);
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

