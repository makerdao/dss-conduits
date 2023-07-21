// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_ReturnFundsTests is ConduitAssetTestBase {

    function test_returnFunds_oneRequest_exact() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 100);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset));
        assertEq(fundRequest.ilk,             ilk);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(asset.balanceOf(arranger),         100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 0);

        _assertInvariants(ilk, address(asset));

        conduit.returnFunds(0, 100);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.asset,           address(asset));
        assertEq(fundRequest.ilk,             ilk);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    100);
        assertEq(fundRequest.info,            "info");

        assertEq(asset.balanceOf(arranger),         0);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset)), 0);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 100);

        _assertInvariants(ilk, address(asset));
    }

    // NOTE: The above test has proven that returnFunds does not change any other values in the
    //       FundRequest struct other than amountFilled and status. Therefore, for subsequent tests
    //       only those two values from the struct will be asserted. `amountRequested` is left in
    //       for easier auditing.

    function test_returnFunds_oneRequest_under() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 100);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset.balanceOf(arranger),         100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 0);

        _assertInvariants(ilk, address(asset));

        conduit.returnFunds(0, 40);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    40);

        assertEq(asset.balanceOf(arranger),         60);
        assertEq(asset.balanceOf(address(conduit)), 40);

        // Goes to zero because amount is reduced by requestedAmount even on partial fills
        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset)), 0);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 40);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 40);

        _assertInvariants(ilk, address(asset));
    }

    // TODO: Write another test with second request getting filled first

    function test_returnFunds_oneIlk_twoRequests_exact_under() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk, address(asset), 20, "info");
        conduit.requestFunds(ilk, address(asset), 80, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 100);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 20);
        assertEq(fundRequest.amountFilled,    0);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 80);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset.balanceOf(arranger),         100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 0);

        _assertInvariants(ilk, address(asset));

        conduit.returnFunds(0, 20);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 20);
        assertEq(fundRequest.amountFilled,    20);

        assertEq(asset.balanceOf(arranger),         80);
        assertEq(asset.balanceOf(address(conduit)), 20);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 80);
        assertEq(conduit.totalRequestedFunds(address(asset)), 80);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 20);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 20);

        _assertInvariants(ilk, address(asset));

        conduit.returnFunds(1, 40);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 80);
        assertEq(fundRequest.amountFilled,    40);

        // Goes to zero because amount is reduced by requestedAmount even on partial fills
        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset)), 0);

        assertEq(conduit.withdrawableFunds(ilk, address(asset)), 60);
        assertEq(conduit.totalWithdrawableFunds(address(asset)), 60);

        _assertInvariants(ilk, address(asset));
    }

    function test_returnFunds_twoIlks_twoRequests_under_over() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        _setupRoles(ilk1, address(this));
        _setupRoles(ilk2, address(this));

        registry.file(ilk1, "buffer", address(this));
        registry.file(ilk2, "buffer", address(this));

        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk1, address(asset), 40);
        conduit.deposit(ilk2, address(asset), 60);

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 100);

        conduit.requestFunds(ilk1, address(asset), 40, "info");
        conduit.requestFunds(ilk2, address(asset), 60, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 20);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset.balanceOf(arranger),         100);
        assertEq(asset.balanceOf(address(conduit)), 0);

        assertEq(conduit.requestedFunds(ilk1, address(asset)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset)), 60);
        assertEq(conduit.totalRequestedFunds(address(asset)),  100);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  0);

        _assertInvariants(ilk1, ilk2, address(asset));

        conduit.returnFunds(0, 20);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    20);

        assertEq(asset.balanceOf(arranger),         80);
        assertEq(asset.balanceOf(address(conduit)), 20);

        // Gets reduced by full ilk1 request
        assertEq(conduit.requestedFunds(ilk1, address(asset)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset)), 60);
        assertEq(conduit.totalRequestedFunds(address(asset)),  60);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 20);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  20);

        _assertInvariants(ilk1, ilk2, address(asset));

        asset.approve(address(conduit), 80);

        conduit.returnFunds(1, 80);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 60);
        assertEq(fundRequest.amountFilled,    80);

        assertEq(asset.balanceOf(arranger),         0);
        assertEq(asset.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(ilk1, address(asset)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset)),  0);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset)), 20);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset)), 80);
        assertEq(conduit.totalWithdrawableFunds(address(asset)),  100);

        _assertInvariants(ilk1, ilk2, address(asset));
    }

    function test_returnFunds_twoIlks_twoAssets_outOfOrder_over_under_under_under() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        _setupRoles(ilk1, address(this));
        _setupRoles(ilk2, address(this));

        registry.file(ilk1, "buffer", address(this));
        registry.file(ilk2, "buffer", address(this));

        MockERC20 asset1 = new MockERC20("asset1", "asset1", 18);
        MockERC20 asset2 = new MockERC20("asset2", "asset2", 18);

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 400);

        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 400);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk1, address(asset2), 100);
        conduit.deposit(ilk2, address(asset2), 300);

        vm.startPrank(arranger);

        conduit.drawFunds(address(asset1), 100);
        conduit.drawFunds(address(asset2), 400);

        vm.stopPrank();

        conduit.requestFunds(ilk1, address(asset1), 40,  "info");
        conduit.requestFunds(ilk2, address(asset1), 60,  "info");
        conduit.requestFunds(ilk1, address(asset2), 100, "info");
        conduit.requestFunds(ilk2, address(asset2), 300, "info");

        /**************************************/
        /*** Before state for all positions ***/
        /**************************************/

        // Ilk 1 asset 1

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    0);

        // Ilk 2 asset 1

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 60);
        assertEq(fundRequest.amountFilled,    0);

        // Ilk 1 asset 2

        fundRequest = conduit.getFundRequest(2);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);

        // Ilk 2 asset 2

        fundRequest = conduit.getFundRequest(3);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 300);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset1.balanceOf(arranger),         100);
        assertEq(asset2.balanceOf(arranger),         400);
        assertEq(asset1.balanceOf(address(conduit)), 0);
        assertEq(asset2.balanceOf(address(conduit)), 0);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 60);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset1)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.withdrawableFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 0);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        /**************************************************************************/
        /*** Return funds for FundRequest 1 BEFORE FundRequest 0 (Over request) ***/
        /**************************************************************************/

        vm.startPrank(arranger);

        asset1.approve(address(conduit), 70);
        conduit.returnFunds(1, 70);

        // Assert that request 0 is untouched

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    0);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 60);
        assertEq(fundRequest.amountFilled,    70);

        assertEq(asset1.balanceOf(arranger),         30);
        assertEq(asset2.balanceOf(arranger),         400);
        assertEq(asset1.balanceOf(address(conduit)), 70);
        assertEq(asset2.balanceOf(address(conduit)), 0);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset1)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset1)), 70);
        assertEq(conduit.withdrawableFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 70);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 0);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        /***************************************************************************/
        /*** Return funds for FundRequest 3 BEFORE FundRequest 2 (Under request) ***/
        /***************************************************************************/

        asset2.approve(address(conduit), 150);
        conduit.returnFunds(3, 150);

        // Assert that request 2 is untouched

        fundRequest = conduit.getFundRequest(2);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);

        fundRequest = conduit.getFundRequest(3);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 300);
        assertEq(fundRequest.amountFilled,    150);

        assertEq(asset1.balanceOf(arranger),         30);
        assertEq(asset2.balanceOf(arranger),         250);
        assertEq(asset1.balanceOf(address(conduit)), 70);
        assertEq(asset2.balanceOf(address(conduit)), 150);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 100);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset1)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset1)), 70);
        assertEq(conduit.withdrawableFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset2)), 150);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 70);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 150);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        /******************************************************/
        /*** Return funds for FundRequest 0 (Under request) ***/
        /******************************************************/

        asset1.approve(address(conduit), 30);
        conduit.returnFunds(0, 30);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    30);

        assertEq(asset1.balanceOf(arranger),         0);
        assertEq(asset2.balanceOf(arranger),         250);
        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 150);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 100);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset1)), 30);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset1)), 70);
        assertEq(conduit.withdrawableFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset2)), 150);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 150);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        /******************************************************/
        /*** Return funds for FundRequest 2 (Under request) ***/
        /******************************************************/

        asset2.approve(address(conduit), 60);
        conduit.returnFunds(2, 60);

        fundRequest = conduit.getFundRequest(2);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    60);

        assertEq(asset1.balanceOf(arranger),         0);
        assertEq(asset2.balanceOf(arranger),         190);
        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 210);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        assertEq(conduit.withdrawableFunds(ilk1, address(asset1)), 30);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset1)), 70);
        assertEq(conduit.withdrawableFunds(ilk1, address(asset2)), 60);
        assertEq(conduit.withdrawableFunds(ilk2, address(asset2)), 150);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 210);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));
    }

}
