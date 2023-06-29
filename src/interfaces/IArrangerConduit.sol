// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IAllocatorConduit } from "../../lib/dss-allocator/src/interfaces/IAllocatorConduit.sol";

/**
 *  @title IArrangerConduit
 *  @dev   Conduits are to be used to manage positions for multiple Allocators.
 *         After funds are deposited into a Conduit, they can be deployed by Arrangers to earn
 *         yield. When Allocators want funds back, they can request funds from the Arrangers and
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
     *  @param data          Arbitrary encoded data to provide additional info to the Arranger.
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
     *  @param data          Arbitrary encoded data to provide additional info to the Arranger.
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
     *  @param asset           The address of the asset requested in the fund request.
     *  @param ilk             The unique identifier of the ilk.
     *  @param amountRequested The amount of asset requested in the fund request.
     *  @param amountFilled    The amount of asset filled in the fund request.
     *  @param info            Arbitrary string to provide additional info to the Arranger.
     */
    struct FundRequest {
        StatusEnum status;
        address    asset;
        bytes32    ilk;
        uint256    amountRequested;
        uint256    amountFilled;
        string     info;
    }

    /**
     *  @dev    Enum representing the status of a fund request.
     *  @notice PENDING   - The fund request has been made, but not yet processed.
     *  @notice CANCELLED - The fund request has been cancelled by the ilk.
     *  @notice COMPLETED - The fund request has been fully processed and completed.
     */
    enum StatusEnum {
        PENDING,
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
     *  @dev    Returns the arranger address.
     *  @return arranger_ The address of the arranger.
     */
    function arranger() external view returns (address arranger_);

    /**
     *  @dev    Returns the roles address.
     *  @return roles_ The address of the roles.
     */
    function roles() external view returns (address roles_);

    /**
     *  @dev    Returns the total deposits for a given asset.
     *  @param  asset          The address of the asset.
     *  @return totalDeposits_ The total deposits held in the asset.
     */
    function totalDeposits(address asset) external view returns (uint256 totalDeposits_);

    /**
     *  @dev    Returns the total requested funds for a given asset.
     *  @param  asset          The address of the asset.
     *  @return totalRequestedFunds_ The total requested funds held in the asset.
     */
    function totalRequestedFunds(address asset)
        external view returns (uint256 totalRequestedFunds_);

    /**
     *  @dev    Returns the total amount that can be withdrawn for a given asset.
     *  @param  asset              The address of the asset.
     *  @return totalWithdrawableFunds_ The total amount that can be withdrawn from the asset.
     */
    function totalWithdrawableFunds(address asset)
        external view returns (uint256 totalWithdrawableFunds_);

    /**
     *  @dev    Returns the total amount of cumulative withdrawals for a given asset.
     *  @param  asset             The address of the asset.
     *  @return totalWithdrawals_ The total amount that can be withdrawn from the asset.
     */
    function totalWithdrawals(address asset)
        external view returns (uint256 totalWithdrawals_);

    /**
     *  @dev    Returns the aggregate deposits for a given ilk and asset.
     *  @param  ilk        The unique identifier for a particular ilk.
     *  @param  asset      The address of the asset.
     *  @return deposits_ The deposits for the given ilk and asset.
     */
    function deposits(bytes32 ilk, address asset) external view returns (uint256 deposits_);

    /**
     *  @dev    Returns the aggregate requested funds for a given ilk and asset.
     *  @param  ilk             The unique identifier for a particular ilk.
     *  @param  asset           The address of the asset.
     *  @return requestedFunds_ The requested funds for the given ilk and asset.
     */
    function requestedFunds(bytes32 ilk, address asset)
        external view returns (uint256 requestedFunds_);

    /**
     *  @dev    Returns the aggregate withdrawable funds for a given ilk and asset.
     *  @param  ilk           The unique identifier for a particular ilk.
     *  @param  asset         The address of the asset.
     *  @return withdrawableFunds_ The withdrawableFunds funds for the given ilk and asset.
     */
    function withdrawableFunds(bytes32 ilk, address asset)
        external view returns (uint256 withdrawableFunds_);

    /**
     *  @dev    Returns the aggregate cumulative withdraws for a given ilk and asset.
     *  @param  ilk          The unique identifier for a particular ilk.
     *  @param  asset        The address of the asset.
     *  @return withdrawals_ The withdrawals funds for the given ilk and asset.
     */
    function withdrawals(bytes32 ilk, address asset) external view returns (uint256 withdrawals_);

    /**********************************************************************************************/
    /*** Router Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     *  @dev    Function to initiate a withdrawal request from a Arranger.
     *  @param  ilk           The unique identifier for a particular ilk.
     *  @param  asset         The asset to withdraw.
     *  @param  amount        The amount of tokens to withdraw.
     *  @param  info          Arbitrary string to provide additional info to the Arranger.
     *  @return fundRequestId The ID of the withdrawal request.
     */
    function requestFunds(bytes32 ilk, address asset, uint256 amount, string memory info)
        external returns (uint256 fundRequestId);

    /**
     *  @dev   Function to cancel a withdrawal request from a Arranger.
     *  @param fundRequestId The ID of the withdrawal request.
     */
    function cancelFundRequest(uint256 fundRequestId) external;

    /**********************************************************************************************/
    /*** Arranger Functions                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Draw funds from the contract to the Arranger.
     * @dev    Only the Arranger is authorized to call this function.
     * @param  asset  The ERC20 token contract address from which funds are being drawn.
     * @param  amount The amount of tokens to be drawn.
     */
    function drawFunds(address asset, uint256 amount) external;

    /**
     * @notice Return funds (principal only) from the Arranger back to the contract.
     * @dev    Only the Arranger is authorized to call this function.
     * @param  fundRequestId The ID of the withdrawal request.
     * @param  amount        The amount of tokens to be returned.
     */
    function returnFunds(uint256 fundRequestId, uint256 amount)
        external;

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev    Function to check if a withdrawal request can be cancelled.
     *  @param  fundRequestId  The ID of the withdrawal request.
     *  @return isCancelable_  True if the withdrawal request can be cancelled, false otherwise.
     */
    function isCancelable(uint256 fundRequestId) external view returns (bool isCancelable_);

}
