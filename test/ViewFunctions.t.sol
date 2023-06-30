// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";
import { Test }                from "../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ArrangerConduitHarness } from "./ArrangerConduitHarness.sol";

import { ConduitTestBase, ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_MaxDepositTests is ConduitTestBase {

    function testFuzz_maxDepositTest(bytes32 ilk, address asset) external {
        assertEq(conduit.maxDeposit(ilk, asset), type(uint256).max);
    }

}

contract Conduit_IsCancelableTest is ConduitAssetTestBase {

    ArrangerConduitHarness conduitHarness;

    function setUp() public override {
        conduitHarness = new ArrangerConduitHarness(arranger, address(registry), address(roles));

        registry.file(ilk, "buffer", address(this));

        roles.setIlkAdmin(ilk, address(this));
        roles.setUserRole(ilk, address(this), ROLE, true);

        address conduit_ = address(conduitHarness);

        roles.setRoleAction(ilk, ROLE, conduit_, conduit.deposit.selector,      true);
        roles.setRoleAction(ilk, ROLE, conduit_, conduit.requestFunds.selector, true);
    }

    function test_isCancelable() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduitHarness), 100);

        conduitHarness.deposit(ilk, address(asset), 100);

        conduitHarness.requestFunds(ilk, address(asset), 100, "info");

        ( IArrangerConduit.StatusEnum status,,,,, ) = conduitHarness.fundRequests(0);

        assertEq(uint256(status), uint256(IArrangerConduit.StatusEnum.PENDING));

        assertEq(conduitHarness.isCancelable(0), true);

        conduitHarness.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(conduitHarness.isCancelable(0), false);

        conduitHarness.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(conduitHarness.isCancelable(0), false);
    }

}
