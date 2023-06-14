// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IConduit } from "./IConduit.sol";

contract Conduit is IConduit {

    function deposit(uint256 amount) external {}

    function isCancelable(uint256 withdrawalId) external view returns (bool isCancelable_) {}

    function initiateWithdraw(uint256 amount) external returns (uint256 withdrawalId) {}

    function cancelWithdraw(uint256 withdrawalId) external {}

    function withdraw(uint256 withdrawalId) external returns (uint256 resultingWithdrawalId) {}

    function withdrawStatus(uint256 withdrawId) external returns (address owner, uint256 amount, StatusEnum status) {}

    function activeWithdraws(address owner) external returns (uint256[] memory withdrawIds, uint256 totalAmount) {}

    function totalActiveWithdraws() external returns (uint256 totalAmount) {}

}
