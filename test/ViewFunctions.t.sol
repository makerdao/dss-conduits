// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";
import { Test }                from "../lib/forge-std/src/Test.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ArrangerConduitHarness } from "./ArrangerConduitHarness.sol";

import { ConduitTestBase, ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_MaxDepositTest is ConduitTestBase {

    function testFuzz_maxDepositTest(bytes32 ilk, address asset) external {
        assertEq(conduit.maxDeposit(ilk, asset), type(uint256).max);
    }

}

contract Conduit_IsCancelabletest is Test {

    address admin    = makeAddr("admin");
    address arranger = makeAddr("arranger");
    address roles    = makeAddr("roles");

    bytes32 ilk = "ilk";

    MockERC20 asset = new MockERC20("asset", "asset", 18);

    ArrangerConduitHarness conduit;

    function setUp() public virtual {
        conduit = new ArrangerConduitHarness(admin, arranger, roles);
    }

    function test_isCancelable() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        ( IArrangerConduit.StatusEnum status,,,,, ) = conduit.fundRequests(0);

        assertEq(uint256(status), uint256(IArrangerConduit.StatusEnum.PENDING));

        assertEq(conduit.isCancelable(0), true);

        conduit.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(conduit.isCancelable(0), false);

        conduit.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(conduit.isCancelable(0), false);
    }

}
