// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import "./ConduitTestBase.sol";

contract ArrangerConduit_ReturnFundsTests is ConduitAssetTestBase {

    function test_returnFunds_notArranger() public {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        vm.expectRevert("ArrangerConduit/not-arranger");
        conduit.returnFunds(0, 100);
    }

    function test_returnFunds_notPending_completed() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        asset1.mint(address(conduit), 100);

        vm.startPrank(arranger);

        conduit.returnFunds(0, 100);

        vm.expectRevert("ArrangerConduit/invalid-status");
        conduit.returnFunds(0, 100);
    }

    function test_returnFunds_notPending_canceled() external {
        _depositAndDrawFunds(100);

        vm.startPrank(operator1);

        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        conduit.cancelFundRequest(0);

        vm.stopPrank();

        vm.prank(arranger);
        vm.expectRevert("ArrangerConduit/invalid-status");
        conduit.returnFunds(0, 100);
    }

    function test_returnFunds_insufficientFundsBoundary() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        asset1.mint(address(conduit), 99);

        vm.startPrank(arranger);
        vm.expectRevert("ArrangerConduit/insufficient-funds");
        conduit.returnFunds(0, 100);

        asset1.mint(address(conduit), 1);

        conduit.returnFunds(0, 100);
    }

    function test_returnFunds_insufficientFundsBoundaryWithWithdrawable() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 60, "info");

        asset1.mint(address(conduit), 99);

        vm.prank(arranger);
        conduit.returnFunds(0, 60);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 40, "info");

        assertEq(conduit.availableFunds(address(asset1)), 39);

        vm.startPrank(arranger);

        vm.expectRevert("ArrangerConduit/insufficient-funds");
        conduit.returnFunds(1, 40);

        asset1.mint(address(conduit), 1);

        assertEq(conduit.availableFunds(address(asset1)), 40);

        conduit.returnFunds(1, 40);
    }

    function test_returnFunds_oneRequest_exact() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        asset1.mint(address(conduit), 100);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);

        assertEq(conduit.availableFunds(address(asset1)), 100);

        _assertInvariants();

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    100);
        assertEq(fundRequest.info,            "info");

        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  100);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();
    }

    // NOTE: The above test has proven that returnFunds does not change any other values in the
    //       FundRequest struct other than amountFilled and status. Therefore, for subsequent tests
    //       only those two values from the struct will be asserted. `amountRequested` is left in
    //       for easier auditing.

    function test_returnFunds_oneRequest_under() external {
        _depositAndDrawFunds(100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        asset1.mint(address(conduit), 40);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset1.balanceOf(address(conduit)), 40);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);

        assertEq(conduit.availableFunds(address(asset1)), 40);

        _assertInvariants();

        vm.prank(arranger);
        conduit.returnFunds(0, 40);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    40);

        assertEq(asset1.balanceOf(address(conduit)), 40);

        // Goes to zero because amount is reduced by requestedAmount even on partial fills
        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 40);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  40);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();
    }

    function test_returnFunds_oneIlk_twoRequests_exact_under() external {
        _depositAndDrawFunds(100);

        vm.startPrank(operator1);

        conduit.requestFunds(ilk1, address(asset1), 20, "info");
        conduit.requestFunds(ilk1, address(asset1), 80, "info");

        vm.stopPrank();

        asset1.mint(address(conduit), 20);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 20);
        assertEq(fundRequest.amountFilled,    0);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 80);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset1.balanceOf(address(conduit)), 20);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);

        assertEq(conduit.availableFunds(address(asset1)), 20);

        _assertInvariants();

        vm.prank(arranger);
        conduit.returnFunds(0, 20);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 20);
        assertEq(fundRequest.amountFilled,    20);

        assertEq(asset1.balanceOf(address(conduit)), 20);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 80);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  80);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 20);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  20);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();

        asset1.mint(address(conduit), 40);

        vm.prank(arranger);
        conduit.returnFunds(1, 40);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 80);
        assertEq(fundRequest.amountFilled,    40);

        assertEq(asset1.balanceOf(address(conduit)), 60);

        // Goes to zero because amount is reduced by requestedAmount even on partial fills
        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 60);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  60);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();
    }

    function test_returnFunds_twoIlks_twoRequests_under_over() external {
        asset1.mint(buffer1, 40);
        asset1.mint(buffer2, 60);

        vm.prank(operator1);
        conduit.deposit(ilk1, address(asset1), 40);

        vm.prank(operator2);
        conduit.deposit(ilk2, address(asset1), 60);

        vm.prank(arranger);
        conduit.drawFunds(address(asset1), broker1, 100);

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 40, "info");

        vm.prank(operator2);
        conduit.requestFunds(ilk2, address(asset1), 60, "info");

        asset1.mint(address(conduit), 20);

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    0);

        assertEq(asset1.balanceOf(address(conduit)), 20);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);

        assertEq(conduit.availableFunds(address(asset1)), 20);

        _assertInvariants();

        vm.prank(arranger);
        conduit.returnFunds(0, 20);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    20);

        assertEq(asset1.balanceOf(address(conduit)), 20);

        // Gets reduced by full ilk1 request
        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  60);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 20);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  20);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();

        asset1.mint(address(conduit), 80);

        vm.prank(arranger);
        conduit.returnFunds(1, 80);

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 60);
        assertEq(fundRequest.amountFilled,    80);

        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 20);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 80);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  100);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();
    }

    // NOTE: This test performs one bulk transfer of assets at the beginning to battle test
    //       accounting under that scenario.
    function test_returnFunds_twoIlks_twoAssets_outOfOrder_over_under_under_under() external {
        asset1.mint(buffer1, 40);
        asset1.mint(buffer2, 60);
        asset2.mint(buffer1, 100);
        asset2.mint(buffer2, 300);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk1, address(asset2), 100);

        vm.stopPrank();

        vm.startPrank(operator2);

        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk2, address(asset2), 300);

        vm.startPrank(arranger);

        conduit.drawFunds(address(asset1), broker1, 100);
        conduit.drawFunds(address(asset2), broker2, 400);

        vm.stopPrank();

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset1), 40,  "info");

        vm.prank(operator2);
        conduit.requestFunds(ilk2, address(asset1), 60,  "info");

        vm.prank(operator1);
        conduit.requestFunds(ilk1, address(asset2), 100, "info");

        vm.prank(operator2);
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

        // Mint all the funds requested into the conduit, they will not correspond to the amounts
        // used in the returnFunds function.
        asset1.mint(address(conduit), 100);
        asset2.mint(address(conduit), 400);

        // Balance assertions are maintained throughout the test to demonstrate no change.
        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 400);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 60);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 0);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 0);

        assertEq(conduit.availableFunds(address(asset1)), 100);
        assertEq(conduit.availableFunds(address(asset2)), 400);

        _assertInvariants();

        /**************************************************************************/
        /*** Return funds for FundRequest 2 BEFORE FundRequest 0 (Over request) ***/
        /**************************************************************************/

        vm.prank(arranger);
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

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 400);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 70);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 70);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 0);

        assertEq(conduit.availableFunds(address(asset1)), 30);
        assertEq(conduit.availableFunds(address(asset2)), 400);

        _assertInvariants();

        /***************************************************************************/
        /*** Return funds for FundRequest 3 BEFORE FundRequest 2 (Under request) ***/
        /***************************************************************************/

        vm.prank(arranger);
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

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 400);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 40);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 70);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk2), 150);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 70);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 150);

        assertEq(conduit.availableFunds(address(asset1)), 30);
        assertEq(conduit.availableFunds(address(asset2)), 250);

        _assertInvariants();

        /******************************************************/
        /*** Return funds for FundRequest 0 (Under request) ***/
        /******************************************************/

        vm.prank(arranger);
        conduit.returnFunds(0, 30);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 40);
        assertEq(fundRequest.amountFilled,    30);

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 400);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 100);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 30);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 70);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk1), 0);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk2), 150);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 150);

        _assertInvariants();

        assertEq(conduit.availableFunds(address(asset1)), 0);
        assertEq(conduit.availableFunds(address(asset2)), 250);

        /******************************************************/
        /*** Return funds for FundRequest 2 (Under request) ***/
        /******************************************************/

        vm.prank(arranger);
        conduit.returnFunds(2, 60);

        fundRequest = conduit.getFundRequest(2);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    60);

        assertEq(asset1.balanceOf(address(conduit)), 100);
        assertEq(asset2.balanceOf(address(conduit)), 400);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset1), ilk2), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk1), 0);
        assertEq(conduit.requestedFunds(address(asset2), ilk2), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 30);
        assertEq(conduit.withdrawableFunds(address(asset1), ilk2), 70);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk1), 60);
        assertEq(conduit.withdrawableFunds(address(asset2), ilk2), 150);

        assertEq(conduit.totalWithdrawableFunds(address(asset1)), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset2)), 210);

        assertEq(conduit.availableFunds(address(asset1)), 0);
        assertEq(conduit.availableFunds(address(asset2)), 190);

        _assertInvariants();
    }

    function test_returnFundsWithoutDrawing() external {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);
        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        vm.stopPrank();

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  100);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  0);

        assertEq(conduit.availableFunds(address(asset1)), 100);

        _assertInvariants();

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    100);
        assertEq(fundRequest.info,            "info");

        assertEq(asset1.balanceOf(address(conduit)), 100);

        assertEq(conduit.requestedFunds(address(asset1), ilk1), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)),  0);

        assertEq(conduit.withdrawableFunds(address(asset1), ilk1), 100);
        assertEq(conduit.totalWithdrawableFunds(address(asset1)),  100);

        assertEq(conduit.availableFunds(address(asset1)), 0);

        _assertInvariants();
    }

}
