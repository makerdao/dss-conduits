// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_RequestFundsTest is ConduitAssetTestBase {

    // bytes32 ilk = "ilk";

    // MockERC20 asset;

    // function setUp() public override {
    //     super.setUp();
    //     asset = new MockERC20("asset", "ASSET", 18);
    // }

    function test_requestFunds_insufficientPositionBoundary() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.expectRevert("Conduit/insufficient-position");
        conduit.requestFunds(ilk, address(asset), 101, new bytes(0));

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));
    }

    function testFuzz_requestFunds_insufficientPositionBoundary(uint256 amount) public {
        vm.assume(amount != 0);

        asset.mint(address(this), amount - 1);
        asset.approve(address(conduit), amount - 1);

        conduit.deposit(ilk, address(asset), amount - 1);

        vm.expectRevert("Conduit/insufficient-position");
        conduit.requestFunds(ilk, address(asset), amount, new bytes(0));

        conduit.requestFunds(ilk, address(asset), amount - 1, new bytes(0));
    }

    function test_requestFunds_singleIlk_singleRequest() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 0);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountAvailable,
            uint256 amountRequested,
            uint256 amountFilled,
            uint256 fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 100);
    }

    function test_requestFunds_singleIlk_multiRequest_insufficientPositionBoundary() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 40, new bytes(0));

        vm.expectRevert("Conduit/insufficient-position");
        conduit.requestFunds(ilk, address(asset), 61, new bytes(0));

        conduit.requestFunds(ilk, address(asset), 60, new bytes(0));
    }

    function test_requestFunds_insufficientPosition_differentIlk() public {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk1, address(asset), 40);

        vm.expectRevert("Conduit/insufficient-position");
        conduit.requestFunds(ilk2, address(asset), 40, new bytes(0));
    }

    function test_requestFunds_insufficientPosition_differentAsset() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 40);

        vm.expectRevert("Conduit/insufficient-position");
        conduit.requestFunds(ilk, address(1), 40, new bytes(0));
    }

    function test_requestFunds_multiIlk_singleRequest_singleAsset() public {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk1, address(asset), 40);
        conduit.deposit(ilk2, address(asset), 60);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)), 0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset), 40, new bytes(0));

        assertEq(returnFundRequestId, 0);

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountAvailable,
            uint256 amountRequested,
            uint256 amountFilled,
            uint256 fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk1);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 40);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset), 60, new bytes(0));

        assertEq(returnFundRequestId, 1);

        (
            status,
            actualIlk,
            amountAvailable,
            amountRequested,
            amountFilled,
            fundRequestId
        ) = conduit.fundRequests(address(asset), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk2);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 60);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   1);
    }

    function test_requestFunds_singleIlk_multiRequest_singleAsset() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk, address(asset), 40, new bytes(0));

        assertEq(returnFundRequestId, 0);

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountAvailable,
            uint256 amountRequested,
            uint256 amountFilled,
            uint256 fundRequestId
        ) = conduit.fundRequests(address(asset), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 40);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 40);

        returnFundRequestId = conduit.requestFunds(ilk, address(asset), 60, new bytes(0));

        assertEq(returnFundRequestId, 1);

        (
            status,
            actualIlk,
            amountAvailable,
            amountRequested,
            amountFilled,
            fundRequestId
        ) = conduit.fundRequests(address(asset), 1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 60);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   1);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 100);
    }

    function test_requestFunds_singleIlk_singleRequest_multiAsset() public {
        MockERC20 asset1 = new MockERC20("asset1", "asset1", 18);
        MockERC20 asset2 = new MockERC20("asset2", "asset2", 18);

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 300);
        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 300);

        conduit.deposit(ilk, address(asset1), 100);
        conduit.deposit(ilk, address(asset2), 300);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset1)), 0);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset2)), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk, address(asset1), 100, new bytes(0));

        assertEq(returnFundRequestId, 0);

        (
            IArrangerConduit.StatusEnum status,
            bytes32 actualIlk,
            uint256 amountAvailable,
            uint256 amountRequested,
            uint256 amountFilled,
            uint256 fundRequestId
        ) = conduit.fundRequests(address(asset1), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset1)), 100);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset2)), 0);

        returnFundRequestId = conduit.requestFunds(ilk, address(asset2), 300, new bytes(0));

        assertEq(returnFundRequestId, 0);  // Also has a zero ID for new asset

        (
            status,
            actualIlk,
            amountAvailable,
            amountRequested,
            amountFilled,
            fundRequestId
        ) = conduit.fundRequests(address(asset2), 0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualIlk,       ilk);
        assertEq(amountAvailable, 0);
        assertEq(amountRequested, 300);
        assertEq(amountFilled,    0);
        assertEq(fundRequestId,   0);

        assertEq(conduit.pendingWithdrawals(ilk, address(asset1)), 100);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset2)), 300);
    }

    function test_requestFunds_multiIlk_multiRequest_multiAsset() public {
        MockERC20 asset1 = new MockERC20("asset1", "asset1", 18);
        MockERC20 asset2 = new MockERC20("asset2", "asset2", 18);

        bytes32 ilk1 = "ilk";
        bytes32 ilk2 = "ilk2";

        /********************************************/
        /*** First round of deposits and requests ***/
        /********************************************/

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 400);

        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 400);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk1, address(asset2), 100);
        conduit.deposit(ilk2, address(asset2), 300);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 0);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 0);

        // Request Funds for asset1 ilk1

        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, new bytes(0));

        assertEq(returnFundRequestId, 0);

        // Removing "constant" assertions from this test to save space and complexity
        ( , bytes32 actualIlk, , uint256 amountRequested, , uint256 fundRequestId ) =
            conduit.fundRequests(address(asset1), 0);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 40);
        assertEq(fundRequestId,   0);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 40);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 0);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 0);

        // Request Funds for asset1 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, new bytes(0));

        assertEq(returnFundRequestId, 1);

        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset1), 1);

        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 60);
        assertEq(fundRequestId,   1);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 40);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 60);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 0);

        // Request Funds for asset2 ilk1

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 100, new bytes(0));

        assertEq(returnFundRequestId, 0);

        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset2), 0);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 100);
        assertEq(fundRequestId,   0);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 40);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 60);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 0);

        // Request Funds for asset2 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset2), 300, new bytes(0));

        assertEq(returnFundRequestId, 1);

        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset2), 1);

        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 300);
        assertEq(fundRequestId,   1);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 40);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 60);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 300);

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 400);

        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 400);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk1, address(asset2), 100);
        conduit.deposit(ilk2, address(asset2), 300);

        /*********************************************/
        /*** Second round of deposits and requests ***/
        /*********************************************/

        // Request Funds for asset1 ilk1

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, new bytes(0));

        assertEq(returnFundRequestId, 2);

        // Removing "constant" assertions from this test to save space and complexity
        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset1), 2);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 40);
        assertEq(fundRequestId,   2);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 80);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 60);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 300);

        // Request Funds for asset1 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, new bytes(0));

        assertEq(returnFundRequestId, 3);

        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset1), 3);

        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 60);
        assertEq(fundRequestId,   3);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 80);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 120);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 300);

        // Request Funds for asset2 ilk1

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 100, new bytes(0));

        assertEq(returnFundRequestId, 2);

        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset2), 2);

        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 100);
        assertEq(fundRequestId,   2);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 80);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 120);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 200);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 300);

        // Request Funds for asset2 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset2), 300, new bytes(0));

        assertEq(returnFundRequestId, 3);

        ( , actualIlk, , amountRequested, , fundRequestId ) =
            conduit.fundRequests(address(asset2), 3);

        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 300);
        assertEq(fundRequestId,   3);

        assertEq(conduit.pendingWithdrawals(ilk1, address(asset1)), 80);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset1)), 120);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset2)), 200);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset2)), 600);
    }
}
