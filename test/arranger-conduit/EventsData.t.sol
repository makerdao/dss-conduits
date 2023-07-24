// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ConduitAssetTestBase } from "./ConduitTestBase.t.sol";

contract ArrangerConduit_WithdrawTests is ConduitAssetTestBase {

    event CancelFundRequest(uint256 fundRequestId);
    event Deposit(bytes32 indexed ilk, address indexed asset, address origin, uint256 amount);
    event DrawFunds(address indexed asset, uint256 amount);
    event RequestFunds(
        bytes32 indexed ilk,
        address indexed asset,
        uint256 fundRequestId,
        uint256 amount,
        string  info
    );
    event ReturnFunds(
        bytes32 indexed ilk,
        address indexed asset,
        uint256 fundRequestId,
        uint256 amountRequested,
        uint256 returnAmount
    );
    event Withdraw(bytes32 indexed ilk, address indexed asset, address destination, uint256 amount);

    function test_cancelFundRequest() public {
        asset.mint(operator, 200);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);
        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.expectEmit(address(conduit));
        emit CancelFundRequest(0);
        conduit.cancelFundRequest(0);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        // Ensure incrementing
        vm.expectEmit(address(conduit));
        emit CancelFundRequest(1);
        conduit.cancelFundRequest(1);
    }

    function test_deposit() external {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);

        vm.expectEmit(address(conduit));
        emit Deposit(ilk, address(asset), operator, 100);
        conduit.deposit(ilk, address(asset), 100);
    }

    function test_drawFunds() public {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);

        vm.stopPrank();

        vm.prank(arranger);
        vm.expectEmit(address(conduit));
        emit DrawFunds(address(asset), 40);
        conduit.drawFunds(address(asset), 40);
    }

    function test_file() public {
        vm.expectEmit(address(conduit));
        emit File("arranger", makeAddr("arranger"));
        conduit.file("arranger", makeAddr("arranger"));
    }

    function test_requestFunds() public {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);

        vm.expectEmit(address(conduit));
        emit RequestFunds(ilk, address(asset), 0, 100, "info");
        conduit.requestFunds(ilk, address(asset), 100, "info");

        // Assert id increments
        vm.expectEmit(address(conduit));
        emit RequestFunds(ilk, address(asset), 1, 50, "info");
        conduit.requestFunds(ilk, address(asset), 50, "info");
    }

    function test_returnFunds() external {
        asset.mint(operator, 100);

        vm.startPrank(operator);

        asset.approve(address(conduit), 100);
        conduit.deposit(ilk, address(asset), 100);

        vm.stopPrank();

        vm.prank(arranger);
        conduit.drawFunds(address(asset), 100);

        vm.prank(operator);
        conduit.requestFunds(ilk, address(asset), 20, "info");

        vm.startPrank(arranger);

        asset.approve(address(conduit), 30);

        // Request 20, return 30
        vm.expectEmit(address(conduit));
        emit ReturnFunds(ilk, address(asset), 0, 20, 30);
        conduit.returnFunds(0, 30);

        vm.stopPrank();

        vm.prank(operator);
        conduit.requestFunds(ilk, address(asset), 50, "info");

        vm.startPrank(arranger);
        asset.approve(address(conduit), 40);

        // Request 50, return 40, assert id increments
        vm.expectEmit(address(conduit));
        emit ReturnFunds(ilk, address(asset), 1, 50, 40);
        conduit.returnFunds(1, 40);
    }

    function test_withdraw() external {
        _depositAndDrawFunds(asset, operator, ilk, 100);

        vm.prank(operator);
        conduit.requestFunds(ilk, address(asset), 100, "info");

        vm.prank(arranger);
        conduit.returnFunds(0, 100);

        vm.prank(operator);
        vm.expectEmit(address(conduit));
        emit Withdraw(ilk, address(asset), operator, 100);
        conduit.withdraw(ilk, address(asset), 100);
    }

}
