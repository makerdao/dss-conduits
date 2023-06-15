// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

/**
 *  @title IConduit
 *  @dev   Interface for the Conduit smart contract.
 */
interface IConduit {

    // TODO: Add events

    event Deposit(bytes32 indexed allocator, address indexed asset, uint256 amount);

    event Withdraw(bytes32 indexed allocator, address indexed asset, address destination, uint256 amount);

    event RequestFunds(bytes32 indexed allocator, address indexed asset, uint256 amount, bytes data, uint256 fundRequestId);

    event CancelRequest(bytes32 indexed allocator, address indexed asset, uint256 amount, bytes data, uint256 fundRequestId);

    event FillRequest(bytes32 indexed allocator, address indexed asset, uint256 amount, bytes data);  // TODO: Investigate if needed

    struct FundRequest {
        StatusEnum status;
        bytes32    allocator;
        uint256    amountRequested;
        uint256    amountFilled;
        uint256    fundRequestId; // NOTE: Investigate usage
    }

    enum StatusEnum {
        PENDING,
        PARTIAL,
        CANCELLED,
        COMPLETED
    }

    /**
     *  @dev   Deposit tokens into a Fund Manager.
     *  @dev   asset  The asset to deposit.
     *  @param amount The amount of tokens to deposit.
     */
    function deposit(bytes32 allocator, address asset, uint256 amount) external;

    // TODO: Update
    function withdraw(bytes32 allocator, address asset, address destination, uint256 amount) external;

    function maxDeposit(bytes32 allocator, address asset) external view returns (uint256 maxDeposit_);

    function maxWithdraw(bytes32 allocator, address asset) external view returns (uint256 maxWithdraw_);

    /**
     *  TODO: Update
     *  @dev    Initiate a withdrawal request from a Fund Manager.
     *  @param  amount        The amount of tokens to withdraw.
     *  @param  data          Arbitrary encoded data to provide additional info to the Fund Manager.
     *  @return fundRequestId The ID of the withdrawal request.
     */
    function requestFunds(bytes32 allocator, address asset, uint256 amount, bytes memory data) external returns (uint256 fundRequestId);

    /**
     *  @dev   Cancel a withdrawal request from a Fund Manager.
     *  @param fundRequestId The ID of the withdrawal request.
     */
    function cancelFundRequest(uint256 fundRequestId) external;

    /**
     *  @dev    Check if a withdrawal request can be cancelled.
     *  @param  fundRequestId  The ID of the withdrawal request.
     *  @return isCancelable_ True if the withdrawal request can be cancelled, false otherwise.
     */
    function isCancelable(uint256 fundRequestId) external view returns (bool isCancelable_);

    /**
     *  @dev    Get the status of a withdrawal request.
     *  @param  fundRequestId The ID of the withdrawal request.
     *  @return owner      The address of the owner of the withdrawal request.
     *  @return amount     The amount of tokens requested for withdrawal.
     *  @return status     The status of the withdrawal request.
     */
    function fundRequestStatus(uint256 fundRequestId) external returns (bytes32 allocator, FundRequest memory fundRequest);

    function activeFundRequests(bytes32 allocator) external returns (uint256[] memory fundRequestIds, uint256 totalAmount);

    /**
     *  @dev    Get the total amount of active withdrawal requests.
     *  @return totalAmount The total amount of tokens requested for withdrawal.
     */
    function totalActiveFundRequests() external returns (uint256 totalAmount);

}
