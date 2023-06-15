// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IConduit } from "./IConduit.sol";

interface ERC20Like {
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}


/**
 * IConduit moves to dss-allocator
 * dss-conduits imports dss-allocator as a library
 * IArrangerConduit is IConduit
 * FIFOConduitBase is IArrangerConduit
 *
 */

contract Conduit is IConduit {

    address public admin;
    address public fundManager;

    uint256 public latestWithdrawalId;

    mapping(address => bool) public isValidRouter;

    mapping(address => bytes32) public routerOwner;

    mapping(address => uint256) public outstandingPrincipal;
    mapping(address => uint256) public totalInterestEarned;
    mapping(address => uint256) public totalPositions;

    mapping(bytes32 => mapping(address => uint256)) public positions;

    constructor(address admin_, address fundManager_) {
        admin       = admin_;
        fundManager = fundManager_;
    }

    /***********************************************************************************************/
    /*** Modifiers                                                                               ***/
    /***********************************************************************************************/

    modifier isAdmin {
        require(msg.sender == admin, "Conduit/not-admin");
        _;
    }

    modifier isFundManager {
        require(msg.sender == fundManager, "Conduit/not-fund-manager");
        _;
    }

    modifier isRouter {
        require(isValidRouter[msg.sender], "Conduit/not-router");
        _;
    }

    /***********************************************************************************************/
    /*** Admin Functions                                                                         ***/
    /***********************************************************************************************/

    function setIsValidRouter(address router, bool isValid) external isAdmin {
        isValidRouter[router] = isValid;
    }

    function setRouterOwner(address router, bytes32 owner) external isAdmin {
        require(isValidRouter[router], "Conduit/not-router");

        routerOwner[router] = owner;
    }

    /***********************************************************************************************/
    /*** Fund Manager Functions                                                                  ***/
    /***********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external isFundManager {
        outstandingPrincipal[asset] += amount;

        require(ERC20Like(asset).transfer(fundManager, amount), "Conduit/transfer-failed");
    }

    function returnFunds(address asset, uint256 amount) external isFundManager {
        outstandingPrincipal[asset] -= amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, address(this), amount),
            "Conduit/transfer-failed"
        );
    }

    function payInterest(address asset, uint256 amount) external isFundManager {
        totalInterestEarned[asset] += amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, admin, amount),
            "Conduit/transfer-failed"
        );
    }

    /***********************************************************************************************/
    /*** Router Functions                                                                        ***/
    /***********************************************************************************************/

    function deposit(address asset, uint256 amount) external isRouter {
        require(
            ERC20Like(asset).transferFrom(msg.sender, address(this), amount),
            "Conduit/transfer-failed"
        );

        positions[routerOwner[msg.sender]][asset] += amount;
        totalPositions[asset]                     += amount;
    }

    function withdraw(address asset, uint256 amount) external isRouter {
        require(
            ERC20Like(asset).transfer(msg.sender, amount),
            "Conduit/transfer-failed"
        );

        positions[routerOwner[msg.sender]][asset] -= amount;
        totalPositions[asset]                     -= amount;
    }

    function isCancelable(uint256 fundRequestId) external view returns (bool isCancelable_) {}

    function requestFunds(uint256 amount, bytes memory data) external returns (uint256 fundRequestId) {}

    function cancelWithdraw(uint256 fundRequestId) external {}

    function withdraw(uint256 fundRequestId) external returns (uint256 resultingFundRequestId) {}

    function withdrawStatus(uint256 withdrawId) external returns (address owner, uint256 amount, StatusEnum status) {}

    function activeWithdraws(address owner) external returns (uint256[] memory withdrawIds, uint256 totalAmount) {}

    function totalActiveWithdraws() external returns (uint256 totalAmount) {}

}

// TODO: Add FIFO logic for requests
