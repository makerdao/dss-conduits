// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IAllocatorConduit } from "../../lib/dss-allocator/src/interfaces/IAllocatorConduit.sol";

/**
 *  @title IArrangerConduit
 *  @dev   Conduits are to be used to manage positions for multiple Allocators.
 *         After funds are deposited into a Conduit, they can be deployed by Fund Managers to earn
 *         yield. When Allocators want funds back, they can request funds from the Fund Managers and
 *         then withdraw once liquidity is available.
 */
interface IArrangerConduit is IAllocatorConduit {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev   Event emitted when a Conduit request is made.
     *  @param ilk           The unique identifier of the ilk.
     *  @param asset         The address of the asset to be withdrawn.
     *  @param amount        The amount of asset to be withdrawn.
     *  @param data          Arbitrary encoded data to provide additional info to the Fund Manager.
     *  @param fundRequestId The ID of the fund request.
     */
    event RequestFunds(
        bytes32 indexed ilk,
        address indexed asset,
        uint256 amount,
        bytes   data,
        uint256 fundRequestId
);

    /**
     *  @dev   Event emitted when a fund request is cancelled.
     *  @param ilk           The unique identifier of the ilk.
     *  @param asset         The address of the asset for the cancelled request.
     *  @param amount        The amount of asset for the cancelled request.
     *  @param data          Arbitrary encoded data to provide additional info to the Fund Manager.
     *  @param fundRequestId The ID of the cancelled fund request.
     */
    event CancelRequest(
        bytes32 indexed ilk,
        address indexed asset,
        uint256 amount,
        bytes   data,
        uint256 fundRequestId
    );

    /**
     *  @dev   Event emitted when a fund request is filled.
     *  @param ilk    The unique identifier of the ilk.
     *  @param asset  The address of the asset for the filled request.
     *  @param amount The amount of asset for the filled request.
     *  @param data   Arbitrary encoded data to provide additional info to the Conduit.
     */
    event FillRequest(bytes32 indexed ilk, address indexed asset, uint256 amount, bytes data);

    /**********************************************************************************************/
    /*** Data Types                                                                             ***/
    /**********************************************************************************************/

    /**
     *  @dev   Struct representing a fund request.
     *  @param status          The current status of the fund request.
     *  @param ilk             The unique identifier of the ilk.
     *  @param amountRequested The amount of asset requested in the fund request.
     *  @param amountFilled    The amount of asset filled in the fund request.
     */
    struct FundRequest {
        StatusEnum status;
        bytes32    ilk;
        uint256    amountRequested;
        uint256    amountFilled;
    }

    /**
     *  @dev    Enum representing the status of a fund request.
     *  @notice PENDING   - The fund request has been made, but not yet processed.
     *  @notice PARTIAL   - The fund request has been partially filled, but not yet completed.
     *  @notice CANCELLED - The fund request has been cancelled by the ilk.
     *  @notice COMPLETED - The fund request has been fully processed and completed.
     */
    enum StatusEnum {
        PENDING,
        PARTIAL,
        CANCELLED,
        COMPLETED
    }

    /**********************************************************************************************/
    /*** Storage Variables                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the admin address of the contract.
     *  @return admin_ The admin address of the contract.
     */
    function admin() external view returns (address admin_);

    /**
     *  @dev    Returns the fund manager address.
     *  @return fundManager_ The address of the fund manager.
     */
    function fundManager() external view returns (address fundManager_);

    /**
     *  @dev    Returns the outstanding principal for a given asset.
     *  @param  asset                 The address of the asset.
     *  @return outstandingPrincipal_ The outstanding principal amount.
     */
    function outstandingPrincipal(address asset)
        external view returns (uint256 outstandingPrincipal_);

    /**
     *  @dev    Returns the starting fund request ID for a given asset.
     *  @param  asset                  The address of the asset.
     *  @return startingFundRequestId_ The ID of the starting fund request.
     */
    function startingFundRequestId(address asset)
        external view returns (uint256 startingFundRequestId_);

    /**
     *  @dev    Returns the total interest earned for a given asset.
     *  @param  asset                The address of the asset.
     *  @return totalInterestEarned_ The total interest earned from the asset.
     */
    function totalInterestEarned(address asset)
        external view returns (uint256 totalInterestEarned_);

    /**
     *  @dev    Returns the total positions for a given asset.
     *  @param  asset            The address of the asset.
     *  @return totalPositions_ The total positions held in the asset.
     */
    function totalPositions(address asset) external view returns (uint256 totalPositions_);

    /**
     *  @dev    Returns the total amount that can be withdrawn for a given asset.
     *  @param  asset              The address of the asset.
     *  @return totalWithdrawable_ The total amount that can be withdrawn from the asset.
     */
    function totalWithdrawable(address asset) external view returns (uint256 totalWithdrawable_);

    /**
     *  @dev    Returns the details of a specific fund request.
     *  @param  asset         The address of the asset.
     *  @param  fundRequestId The ID of the fund request.
     *  @return fundRequest_  The details of the fund request.
     */
    // TODO: Figure out how to get this to compile
    // function fundRequests(address asset, uint256 fundRequestId)
    //     external view returns (FundRequest[] memory fundRequest_);

    /**
     *  @dev    Returns the pending withdrawals for a given asset and allocator.
     *  @param  ilk                 The unique identifier of the for a particular ilk.
     *  @param  asset               The address of the asset.
     *  @return pendingWithdrawals_ The amount of pending withdrawals for the allocator.
     */
    function pendingWithdrawals(bytes32 ilk, address asset)
        external view returns (uint256 pendingWithdrawals_);

    /**
     *  @dev    Returns the position for a given ilk and asset.
     *  @param  ilk        The unique identifier of the for a particular ilk.
     *  @param  asset      The address of the asset.
     *  @return positions_ The positions for the given ilk and asset.
     */
    function positions(bytes32 ilk, address asset) external view returns (uint256 positions_);

    /**********************************************************************************************/
    /*** Router Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     *  @dev    Function to initiate a withdrawal request from a Fund Manager.
     *  @param  ilk           The unique identifier of the for a particular ilk.
     *  @param  asset         The asset to withdraw.
     *  @param  amount        The amount of tokens to withdraw.
     *  @param  data          Arbitrary encoded data to provide additional info to the Fund Manager.
     *  @return fundRequestId The ID of the withdrawal request.
     */
    function requestFunds(bytes32 ilk, address asset, uint256 amount, bytes memory data)
        external returns (uint256 fundRequestId);

    /**
     *  @dev   Function to cancel a withdrawal request from a Fund Manager.
     *  @param asset         The asset to cancel the fund request for.
     *  @param fundRequestId The ID of the withdrawal request.
     */
    function cancelFundRequest(address asset, uint256 fundRequestId) external;

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Draw funds from the contract to the Fund Manager.
     * @dev   Only the Fund Manager is authorized to call this function.
     * @param asset  The ERC20 token contract address from which funds are being drawn.
     * @param amount The amount of tokens to be drawn.
     */
    function drawFunds(address asset, uint256 amount) external;

    /**
     * @notice Return funds (principal only) from the Fund Manager back to the contract.
     * @dev   Only the Fund Manager is authorized to call this function.
     * @param asset  The ERC20 token contract address of the funds being returned.
     * @param amount The amount of tokens to be returned.
     */
    function returnFunds(address asset, uint256 amount) external;

    /**
     * @notice Pay interest to the admin of the contract.
     * @dev   Only the Fund Manager is authorized to call this function.
     * @param asset  The ERC20 token contract address from which interest is paid.
     * @param amount The amount of tokens to be paid as interest.
     */
    function payInterest(address asset, uint256 amount) external;

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Function to check if a withdrawal request can be cancelled.
     *  @param  asset          The asset to check.
     *  @param  fundRequestId  The ID of the withdrawal request.
     *  @return isCancelable_  True if the withdrawal request can be cancelled, false otherwise.
     */
    function isCancelable(address asset, uint256 fundRequestId)
        external view returns (bool isCancelable_);

    /**
     *  @dev    Function to get the active fund requests for a particular ilk.
     *  @param  asset          The address of the asset.
     *  @param  ilk            The unique identifier of the for a particular ilk.
     *  @return fundRequestIds Array of the IDs of active fund requests.
     *  @return totalRequested The total amount of tokens requested in the active fund requests.
     *  @return totalAvailable The total amount of tokens available in the active fund requests.
     */
    function activeFundRequests(address asset, bytes32 ilk)
        external view returns (
            uint256[] memory fundRequestIds,
            uint256 totalRequested,
            uint256 totalAvailable
        );

    /**
     *  @dev    Function to get the total amount of active withdrawal requests.
     *  @param  asset          The asset to check.
     *  @return totalRequested The total amount of tokens requested in the active fund requests.
     *  @return totalFilled    The total amount of tokens available in the active fund requests.
     */
    function totalActiveFundRequests(address asset)
        external view returns (uint256 totalRequested, uint256 totalFilled);

}
