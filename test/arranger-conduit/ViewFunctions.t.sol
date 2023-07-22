// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { UpgradeableProxy } from "../../lib/upgradeable-proxy/src/UpgradeableProxy.sol";

import { console2 as console } from "../../lib/forge-std/src/console2.sol";
import { Test }                from "../../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import { ArrangerConduitHarness } from "./ArrangerConduitHarness.sol";

import { ConduitTestBase, ConduitAssetTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_MaxDepositTests is ConduitTestBase {

    function testFuzz_maxDepositTest(bytes32 ilk, address asset) external {
        assertEq(conduit.maxDeposit(ilk, asset), type(uint256).max);
    }

}

contract ArrangerConduit_IsCancelableTest is ConduitAssetTestBase {

    ArrangerConduitHarness conduitHarness;

    function setUp() public override {
        UpgradeableProxy       conduitProxy          = new UpgradeableProxy();
        ArrangerConduitHarness conduitImplementation = new ArrangerConduitHarness();

        conduitProxy.setImplementation(address(conduitImplementation));

        conduitHarness = ArrangerConduitHarness(address(conduitProxy));

        registry.file(ilk, "buffer", address(this));

        conduitHarness.file("registry", address(registry));
        conduitHarness.file("roles",   address(roles));

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

        IArrangerConduit.FundRequest memory fundRequest = conduitHarness.getFundRequest(0);

        assertEq(uint256(fundRequest.status), uint256(IArrangerConduit.StatusEnum.PENDING));

        assertEq(conduitHarness.isCancelable(0), true);

        conduitHarness.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(conduitHarness.isCancelable(0), false);

        conduitHarness.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(conduitHarness.isCancelable(0), false);
    }

}

contract ArrangerConduit_GetFundRequestsLengthTest is ConduitAssetTestBase {

    function test_getFundRequestsLength() external {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);

        assertEq(conduit.getFundRequestsLength(), 0);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        assertEq(conduit.getFundRequestsLength(), 1);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        assertEq(conduit.getFundRequestsLength(), 2);

        vm.startPrank(arranger);

        conduit.drawFunds(address(asset), 100);
        asset.approve(address(conduit), 100);
        conduit.returnFunds(0, 40);

        assertEq(conduit.getFundRequestsLength(), 2);  // Returning funds does not change length
    }

}

contract ArrangerConduit_MaxWithdrawTest is ConduitAssetTestBase {

    ArrangerConduitHarness conduitHarness;

    function setUp() public override {
        UpgradeableProxy       conduitProxy          = new UpgradeableProxy();
        ArrangerConduitHarness conduitImplementation = new ArrangerConduitHarness();

        conduitProxy.setImplementation(address(conduitImplementation));

        conduitHarness = ArrangerConduitHarness(address(conduitProxy));
    }

    function testFuzz_maxWithdraw(
        address asset1,
        address asset2,
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    )
        external
    {
        vm.assume(asset1 != asset2);
        // address asset1 = 0x0000000000000000000000000000000000000536;
        // address asset2 = 0x0000000000000000000000000000000000000536;
        // uint256 amount1 = 37895166965615977881614845983;
        // uint256 amount2 = 1664836206;
        // uint256 amount3 = 37895166965615977881614845983;

        conduitHarness.__setWithdrawableFunds(ilk, asset1, amount1);
        conduitHarness.__setWithdrawableFunds(ilk, asset2, amount2);

        console.log("maxWithdraw(ilk, asset1):", conduitHarness.maxWithdraw(ilk, asset1));
        console.log("maxWithdraw(ilk, asset2):", conduitHarness.maxWithdraw(ilk, asset2));

        console.log("withdrawableFunds(ilk, asset1):", conduitHarness.withdrawableFunds(ilk, asset1));
        console.log("withdrawableFunds(ilk, asset2):", conduitHarness.withdrawableFunds(ilk, asset2));

        console.log("amount1:", amount1);
        console.log("amount2:", amount2);

        assertEq(conduitHarness.maxWithdraw(ilk, asset1), amount1);
        assertEq(conduitHarness.maxWithdraw(ilk, asset2), amount2);

        amount3 = _bound(amount3, 0, type(uint256).max - amount1);

        conduitHarness.__setWithdrawableFunds(ilk, asset1, amount1 + amount3);

        assertEq(conduitHarness.maxWithdraw(ilk, asset1), amount1 + amount3);
    }

}
