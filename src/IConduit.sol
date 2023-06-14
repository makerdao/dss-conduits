// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

/**
 *  @title IConduit
 *  @dev   Interface for the Conduit smart contract.
 */
interface IConduit {

    enum StatusEnum {
        PENDING,
        CANCELLED,
        EXECUTED
    }

    /**
     *  @dev   Deposit tokens into a Fund Manager.
     *  @param amount The amount of tokens to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     *  @dev    Check if a withdrawal request can be cancelled.
     *  @param  withdrawalId  The ID of the withdrawal request.
     *  @return isCancelable_ True if the withdrawal request can be cancelled, false otherwise.
     */
    function isCancelable(uint256 withdrawalId) external view returns (bool isCancelable_);

    /**
     *  @dev    Initiate a withdrawal request from a Fund Manager.
     *  @param  amount       The amount of tokens to withdraw.
     *  @return withdrawalId The ID of the withdrawal request.
     */
    function initiateWithdraw(uint256 amount) external returns (uint256 withdrawalId);

    /**
     *  @dev   Cancel a withdrawal request from a Fund Manager.
     *  @param withdrawalId The ID of the withdrawal request.
     */
    function cancelWithdraw(uint256 withdrawalId) external;

    /**
     *  @dev    Withdraw tokens from a Fund Manager.
     *  @param  withdrawalId          The ID of the withdrawal request.
     *  @return resultingWithdrawalId The resulting ID of the withdrawal request.
     */
    function withdraw(uint256 withdrawalId) external returns (uint256 resultingWithdrawalId);

    /**
     *  @dev    Get the status of a withdrawal request.
     *  @param  withdrawId The ID of the withdrawal request.
     *  @return owner      The address of the owner of the withdrawal request.
     *  @return amount     The amount of tokens requested for withdrawal.
     *  @return status     The status of the withdrawal request.
     */
    function withdrawStatus(uint256 withdrawId) external returns (address owner, uint256 amount, StatusEnum status);

    /**
     *  @dev    Get the active withdrawal requests for a specific owner.
     *  @param  owner       The address of the owner of the withdrawal requests.
     *  @return withdrawIds An array of withdrawal request IDs.
     *  @return totalAmount The total amount of tokens requested for withdrawal.
     */
    function activeWithdraws(address owner) external returns (uint256[] memory withdrawIds, uint256 totalAmount);

    /**
     *  @dev    Get the total amount of active withdrawal requests.
     *  @return totalAmount The total amount of tokens requested for withdrawal.
     */
    function totalActiveWithdraws() external returns (uint256 totalAmount);

}
