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

    address admin       = makeAddr("admin");
    address fundManager = makeAddr("fundManager");

    bytes32 ilk = "ilk";

    MockERC20 asset = new MockERC20("asset", "asset", 18);

    ArrangerConduitHarness conduit;

    function setUp() public virtual {
        conduit = new ArrangerConduitHarness(admin, fundManager);
    }

    function test_isCancelable() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        ( IArrangerConduit.StatusEnum status,,, ) = conduit.fundRequests(address(asset), 0);

        assertEq(uint256(status), uint256(IArrangerConduit.StatusEnum.PENDING));

        assertEq(conduit.isCancelable(address(asset), 0), true);

        conduit.__setFundRequestStatus(address(asset), 0, IArrangerConduit.StatusEnum.PARTIAL);

        assertEq(conduit.isCancelable(address(asset), 0), true);

        conduit.__setFundRequestStatus(address(asset), 0, IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(conduit.isCancelable(address(asset), 0), false);

        conduit.__setFundRequestStatus(address(asset), 0, IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(conduit.isCancelable(address(asset), 0), false);
    }

}

contract Conduit_ActiveFundRequests is ConduitAssetTestBase {

    bytes32 ilk1 = "ilk1";
    bytes32 ilk2 = "ilk2";

    function test_activeFundRequests() external {
        _depositAndDrawFunds(asset, ilk1, 100);
        _depositAndDrawFunds(asset, ilk2, 400);
        _depositAndDrawFunds(asset, ilk1, 500);

        conduit.requestFunds(ilk1, address(asset), 100, new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 400, new bytes(0));
        conduit.requestFunds(ilk1, address(asset), 500, new bytes(0));

        // Ilk 1

        ( uint256[] memory fundRequestIds, uint256 totalRequested, uint256 totalFilled )
            = conduit.activeFundRequests(address(asset), ilk1);

        assertEq(fundRequestIds.length, 2);
        assertEq(fundRequestIds[0],     0);
        assertEq(fundRequestIds[1],     2);
        assertEq(totalRequested,        600);
        assertEq(totalRequested,        600);
        assertEq(totalFilled,           0);

        // Ilk 2

        ( fundRequestIds, totalRequested, totalFilled )
            = conduit.activeFundRequests(address(asset), ilk2);

        assertEq(fundRequestIds.length, 1);
        assertEq(fundRequestIds[0],     1);
        assertEq(totalRequested,        400);
        assertEq(totalFilled,           0);

        // Cancel middle request

        conduit.cancelFundRequest(address(asset), 1);

        // Ilk 1

        ( fundRequestIds, totalRequested, totalFilled )
            = conduit.activeFundRequests(address(asset), ilk1);

        assertEq(fundRequestIds.length, 2);
        assertEq(fundRequestIds[0],     0);
        assertEq(fundRequestIds[1],     2);
        assertEq(totalRequested,        600);
        assertEq(totalRequested,        600);
        assertEq(totalFilled,           0);

        // Ilk 2

        vm.expectRevert("Conduit/no-active-fund-requests");
        ( fundRequestIds, totalRequested, totalFilled )
            = conduit.activeFundRequests(address(asset), ilk2);

        // Partially fill first request

        vm.startPrank(fundManager);
        asset.approve(address(conduit), 50);

        conduit.returnFunds(address(asset), 50);

        ( fundRequestIds, totalRequested, totalFilled )
            = conduit.activeFundRequests(address(asset), ilk1);

        assertEq(fundRequestIds.length, 2);
        assertEq(fundRequestIds[0],     0);
        assertEq(fundRequestIds[1],     2);
        assertEq(totalRequested,        600);
        assertEq(totalRequested,        600);
        assertEq(totalFilled,           0);
    }
}

contract Conduit_TotalActiveFundRequests is ConduitAssetTestBase {

    bytes32 ilk1 = "ilk1";
    bytes32 ilk2 = "ilk2";

    function test_totalActiveFundRequests() external {
        _depositAndDrawFunds(asset, ilk1, 100);
        _depositAndDrawFunds(asset, ilk2, 400);
        _depositAndDrawFunds(asset, ilk1, 500);

        conduit.requestFunds(ilk1, address(asset), 100, new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 400, new bytes(0));
        conduit.requestFunds(ilk1, address(asset), 500, new bytes(0));

        ( uint256 totalRequested, uint256 totalFilled )
            = conduit.totalActiveFundRequests(address(asset));

        assertEq(totalRequested, 1000);
        assertEq(totalFilled,    0);

        // Cancel middle request

        conduit.cancelFundRequest(address(asset), 1);

        ( totalRequested, totalFilled ) = conduit.totalActiveFundRequests(address(asset));

        assertEq(totalRequested, 600);
        assertEq(totalFilled,    0);

        // Partially fill first request

        vm.startPrank(fundManager);
        asset.approve(address(conduit), 50);

        conduit.returnFunds(address(asset), 50);

        ( totalRequested, totalFilled ) = conduit.totalActiveFundRequests(address(asset));

        assertEq(totalRequested, 600);
        assertEq(totalFilled,    50);

        // Fully fill first request, partially fill third request

        asset.approve(address(conduit), 200);

        conduit.returnFunds(address(asset), 200);

        ( totalRequested, totalFilled ) = conduit.totalActiveFundRequests(address(asset));

        // Total requested goes down because of filled request
        assertEq(totalRequested, 500);
        assertEq(totalFilled,    150);

        // Add another request

        vm.stopPrank();

        _depositAndDrawFunds(asset, ilk2, 500);
        conduit.requestFunds(ilk2, address(asset), 500, new bytes(0));

        ( totalRequested, totalFilled ) = conduit.totalActiveFundRequests(address(asset));

        assertEq(totalRequested, 1000);
        assertEq(totalFilled,    150);

        // Fully fill all requests

        vm.startPrank(fundManager);
        asset.approve(address(conduit), 850);

        conduit.returnFunds(address(asset), 850);

        ( totalRequested, totalFilled ) = conduit.totalActiveFundRequests(address(asset));

        assertEq(totalRequested, 0);
        assertEq(totalFilled,    0);
    }
}
