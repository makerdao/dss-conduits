// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_WithdrawTest is ConduitAssetTestBase {

    function test_withdraw_insufficientAvailableWithdrawalBoundary() external {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        vm.startPrank(fundManager);
        conduit.drawFunds(address(asset), 100);

        asset.approve(address(conduit), 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        conduit.returnFunds(address(asset), 99);

        vm.expectRevert("Conduit/insufficient-withdrawal");
        conduit.withdraw(ilk, address(asset), address(this), 100);

        conduit.returnFunds(address(asset), 1);

        conduit.withdraw(ilk, address(asset), address(this), 100);
    }

    // TODO: Determine if failure from insufficient balance is possible

    function test_withdraw_oneRequest_complete() external {
        _depositAndDrawFunds(asset, ilk, 100);

        conduit.requestFunds(ilk, address(asset), 100, new bytes(0));

        vm.prank(fundManager);
        conduit.returnFunds(address(asset), 100);

        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(address(this)),    0);

        assertEq(conduit.maxWithdraw(ilk, address(asset)),        100);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 100);
        assertEq(conduit.positions(ilk, address(asset)),          100);
        assertEq(conduit.totalPositions(address(asset)),          100);
        assertEq(conduit.totalWithdrawable(address(asset)),       100);

        conduit.withdraw(ilk, address(asset), address(this), 100);

        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(address(this)),    100);

        assertEq(conduit.maxWithdraw(ilk, address(asset)),        0);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 0);
        assertEq(conduit.positions(ilk, address(asset)),          0);
        assertEq(conduit.totalPositions(address(asset)),          0);
        assertEq(conduit.totalWithdrawable(address(asset)),       0);
    }

    function test_withdraw_twoRequests_complete_partial() external {
        _depositAndDrawFunds(asset, ilk, 100);

        conduit.requestFunds(ilk, address(asset), 40, new bytes(0));
        conduit.requestFunds(ilk, address(asset), 60, new bytes(0));

        vm.prank(fundManager);
        conduit.returnFunds(address(asset), 70);

        assertEq(asset.balanceOf(fundManager),      30);
        assertEq(asset.balanceOf(address(conduit)), 70);
        assertEq(asset.balanceOf(address(this)),    0);

        assertEq(conduit.maxWithdraw(ilk, address(asset)),        70);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 100);
        assertEq(conduit.positions(ilk, address(asset)),          100);
        assertEq(conduit.totalPositions(address(asset)),          100);
        assertEq(conduit.totalWithdrawable(address(asset)),       70);

        // TODO: Investigate partial withdrawals
        conduit.withdraw(ilk, address(asset), address(this), 70);

        assertEq(asset.balanceOf(fundManager),      30);
        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(address(this)),    70);

        assertEq(conduit.maxWithdraw(ilk, address(asset)),        0);
        assertEq(conduit.pendingWithdrawals(ilk, address(asset)), 30);
        assertEq(conduit.positions(ilk, address(asset)),          30);
        assertEq(conduit.totalPositions(address(asset)),          30);
        assertEq(conduit.totalWithdrawable(address(asset)),       0);
    }

    function test_withdraw_twoIlks_complete_complete_complete_partial() external {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        address dest1 = makeAddr("destination1");
        address dest2 = makeAddr("destination2");

        _depositAndDrawFunds(asset, ilk1, 100);
        _depositAndDrawFunds(asset, ilk2, 400);

        conduit.requestFunds(ilk1, address(asset), 40,  new bytes(0));
        conduit.requestFunds(ilk1, address(asset), 60,  new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 100, new bytes(0));
        conduit.requestFunds(ilk2, address(asset), 300, new bytes(0));

        vm.prank(fundManager);
        conduit.returnFunds(address(asset), 310);

        assertEq(asset.balanceOf(fundManager),      190);
        assertEq(asset.balanceOf(address(conduit)), 310);
        assertEq(asset.balanceOf(dest1),            0);

        assertEq(conduit.maxWithdraw(ilk1, address(asset)),        100);
        assertEq(conduit.maxWithdraw(ilk2, address(asset)),        210);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)), 100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)), 400);
        assertEq(conduit.positions(ilk1, address(asset)),          100);
        assertEq(conduit.positions(ilk2, address(asset)),          400);
        assertEq(conduit.totalPositions(address(asset)),           500);
        assertEq(conduit.totalWithdrawable(address(asset)),        310);

        // Demonstrate that withdrawal order is dependent on the order in which the requests are
        // made, not the order of actioned withdrawals. There is enough funds to fulfill ilk2's
        // withdrawal of 211 (300 balance and 300 pending withdraw), but since 100 is earmarked for
        // ilk1, ilk2 can only withdraw a max of 190.
        vm.expectRevert("Conduit/insufficient-withdrawal");
        conduit.withdraw(ilk2, address(asset), dest2, 211);

        conduit.withdraw(ilk2, address(asset), dest2, 210);

        assertEq(asset.balanceOf(fundManager),      190);
        assertEq(asset.balanceOf(address(conduit)), 100);
        assertEq(asset.balanceOf(dest1),            0);
        assertEq(asset.balanceOf(dest2),            210);

        assertEq(conduit.maxWithdraw(ilk1, address(asset)),        100);
        assertEq(conduit.maxWithdraw(ilk2, address(asset)),        0);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)), 100);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)), 190);
        assertEq(conduit.positions(ilk1, address(asset)),          100);
        assertEq(conduit.positions(ilk2, address(asset)),          190);
        assertEq(conduit.totalPositions(address(asset)),           290);
        assertEq(conduit.totalWithdrawable(address(asset)),        100);

        conduit.withdraw(ilk1, address(asset), dest1, 100);

        assertEq(asset.balanceOf(fundManager),      190);
        assertEq(asset.balanceOf(address(conduit)), 0);
        assertEq(asset.balanceOf(dest1),            100);
        assertEq(asset.balanceOf(dest2),            210);

        assertEq(conduit.maxWithdraw(ilk1, address(asset)),        0);
        assertEq(conduit.maxWithdraw(ilk2, address(asset)),        0);
        assertEq(conduit.pendingWithdrawals(ilk1, address(asset)), 0);
        assertEq(conduit.pendingWithdrawals(ilk2, address(asset)), 190);
        assertEq(conduit.positions(ilk1, address(asset)),          0);
        assertEq(conduit.positions(ilk2, address(asset)),          190);
        assertEq(conduit.totalPositions(address(asset)),           190);
        assertEq(conduit.totalWithdrawable(address(asset)),        0);
    }

}

contract Conduit_WithdrawFuzzTest is ConduitAssetTestBase {

    bytes32 ilk1 = "ilk1";
    bytes32 ilk2 = "ilk2";

    address dest1 = makeAddr("destination1");
    address dest2 = makeAddr("destination2");

    uint256 ilk1DepositSum;
    uint256 ilk2DepositSum;

    uint256 ilk1RequestSum;
    uint256 ilk2RequestSum;

    uint256 ilk1WithdrawSum;
    uint256 ilk2WithdrawSum;

    function testFuzz_withdraw(
        // uint256[1] memory ilk1Amounts,
        // uint256[1] memory ilk2Amounts,
        // uint256 returnAmount
    )
        external
    {
        uint256[1] memory ilk1Amounts = [uint256(100)];
        uint256[1] memory ilk2Amounts = [uint256(300)];

        uint256 returnAmount = 200;

        for(uint256 i; i < ilk1Amounts.length; i++) {
            _depositAndDrawFunds(asset, ilk1, ilk1Amounts[i]);
            _depositAndDrawFunds(asset, ilk2, ilk2Amounts[i]);

            ilk1DepositSum += ilk1Amounts[i];
            ilk2DepositSum += ilk2Amounts[i];

            assertEq(asset.balanceOf(fundManager),      ilk1DepositSum + ilk2DepositSum);
            assertEq(asset.balanceOf(address(conduit)), 0);

            assertEq(conduit.positions(ilk1, address(asset)), ilk1DepositSum);
            assertEq(conduit.positions(ilk2, address(asset)), ilk2DepositSum);
            assertEq(conduit.totalPositions(address(asset)),  ilk1DepositSum + ilk2DepositSum);
        }

        for (uint256 i; i < ilk1Amounts.length; i++) {
            uint256 amount1 = _bound(uint256(keccak256(abi.encode(ilk1Amounts[i]))), 0, ilk1Amounts[i]);
            uint256 amount2 = _bound(uint256(keccak256(abi.encode(ilk2Amounts[i]))), 0, ilk2Amounts[i]);

            conduit.requestFunds(ilk1, address(asset), amount1, new bytes(0));
            conduit.requestFunds(ilk2, address(asset), amount2, new bytes(0));

            ilk1RequestSum += amount1;
            ilk2RequestSum += amount2;

            assertEq(conduit.pendingWithdrawals(ilk1, address(asset)), ilk1RequestSum);
            assertEq(conduit.pendingWithdrawals(ilk2, address(asset)), ilk2RequestSum);

            // Ilk 1 fund request

            ( IArrangerConduit.StatusEnum status, , uint256 amountRequested , )
                = conduit.fundRequests(address(asset), i * 2);

            assertTrue(status == IArrangerConduit.StatusEnum.PENDING);
            assertEq(amountRequested, amount1);

            // Ilk 2 fund request

            ( status, , amountRequested , )
                = conduit.fundRequests(address(asset), i * 2 + 1);

            assertTrue(status == IArrangerConduit.StatusEnum.PENDING);
            assertEq(amountRequested, amount2);
        }

        vm.startPrank(fundManager);
        asset.approve(address(conduit), returnAmount);
        conduit.returnFunds(address(asset), returnAmount);

        uint256 filledSum;

        for (uint256 i; i < ilk1Amounts.length * 2; i++) {
            (
                IArrangerConduit.StatusEnum status,
                ,
                uint256 amountRequested,
                uint256 amountFilled
            ) = conduit.fundRequests(address(asset), i);

            uint256 amount = i % 2 == 0 ? ilk1Amounts[i / 2] : ilk2Amounts[i / 2];

            uint256 requestedAmount = _bound(uint256(keccak256(abi.encode(amount))), 0, amount);

            uint256 filledAmount
                = requestedAmount <= (returnAmount - filledSum)
                ? requestedAmount
                : (returnAmount - filledSum);

            assertEq(amountRequested, requestedAmount);
            assertEq(amountFilled,    filledAmount);  // TODO: Change amount filled to be amountAvailable, remove ID

            filledSum += filledAmount;

            IArrangerConduit.StatusEnum expectedStatus;

            if (filledAmount == 0) expectedStatus = IArrangerConduit.StatusEnum.PENDING;

            else if (filledAmount == requestedAmount) {
                expectedStatus = IArrangerConduit.StatusEnum.COMPLETED;
            }

            else if (filledAmount < requestedAmount) {
                expectedStatus = IArrangerConduit.StatusEnum.PARTIAL;
            }

            else if (filledAmount > requestedAmount) revert("filledAmount > requestedAmount");

            assertTrue(status == expectedStatus);
        }

        for (uint256 i; i < ilk1Amounts.length * 2; i++) {
            ( , , uint256 amountRequested, uint256 amountFilled )  // TODO: Investigate unused var
                = conduit.fundRequests(address(asset), i);

            uint256 withdrawAmount
                = _bound(uint256(keccak256(abi.encode(amountFilled))), 0, amountFilled);

            address dest = i % 2 == 0 ? dest1 : dest2;
            bytes32 ilk  = i % 2 == 0 ? ilk1  : ilk2;

            conduit.withdraw(ilk, address(asset), dest, withdrawAmount);

            ilk1WithdrawSum += i % 2 == 0 ? withdrawAmount : 0;
            ilk2WithdrawSum += i % 2 == 1 ? withdrawAmount : 0;

            assertEq(
                conduit.maxWithdraw(ilk1, address(asset)) +
                conduit.maxWithdraw(ilk2, address(asset)),
                conduit.totalWithdrawable(address(asset))
            );

            assertEq(
                conduit.positions(ilk1, address(asset)) +
                conduit.positions(ilk2, address(asset)),
                conduit.totalPositions(address(asset))
            );

            assertEq(conduit.pendingWithdrawals(ilk1, address(asset)), ilk1RequestSum - ilk1WithdrawSum);
            assertEq(conduit.pendingWithdrawals(ilk2, address(asset)), ilk2RequestSum - ilk2WithdrawSum);

            assertEq(conduit.outstandingPrincipal(address(asset)), asset.balanceOf(fundManager));

            assertEq(
                conduit.outstandingPrincipal(address(asset)),
                conduit.totalPositions(address(asset)) - conduit.totalWithdrawable(address(asset))
            );

            assertEq(conduit.maxWithdraw(ilk, address(asset)), amountFilled - withdrawAmount);
        }
    }

}
