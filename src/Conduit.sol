// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IConduit } from "./IConduit.sol";

interface ERC20Like {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract Conduit is IConduit {

    struct {
        uint256 cash;
        uint256 outstanding;
    }

    address public admin;
    address public fundManager;

    uint256 public latestWithdrawalId;

    mapping(address => bool) public isValidRouter;

    mapping(address => uint256) public totalPositions;

    mapping(address => mapping(address => uint256)) public positions;

    constructor(address admin_, address fundManager_) {
        admin       = admin_;
        fundManager = fundManager_;
    }

    /***************************************************************************************************/
    /*** Modifiers                                                                                   ***/
    /***************************************************************************************************/

    modifier isAdmin {
        require(msg.sender == admin, "Conduit/not-admin");
        _;
    }

    modifier isFundManager {
        require(msg.sender == fundManager, "Conduit/not-router");
        _;
    }

    modifier isRouter {
        require(isValidRouter[msg.sender], "Conduit/not-router");
        _;
    }

    /***************************************************************************************************/
    /*** Admin Functions                                                                             ***/
    /***************************************************************************************************/

    function setIsValidRouter(address router, bool isValid) external isAdmin {
        isValidRouter[router] = isValid;
    }

    /***************************************************************************************************/
    /*** Fund Manager Functions                                                                      ***/
    /***************************************************************************************************/

    function drawFunds(address asset, uint256 amount) external isFundManager {
        outstandingPrincipal += amount;

        require(ERC20Like(asset).transfer(fundManager, amount), "Conduit/transfer-failed");
    }

    function returnFunds(address asset, uint256 amount) external isFundManager {
        outstandingPrincipal -= amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, address(this), amount),
            "Conduit/transfer-failed"
        );
    }

    function payInterest(address asset, uint256 amount) external isFundManager {
        totalInterestEarned += amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, admin, amount),
            "Conduit/transfer-failed"
        );
    }

    /***************************************************************************************************/
    /*** Router Functions                                                                            ***/
    /***************************************************************************************************/

    function deposit(address asset, uint256 amount) external isRouter {
        require(
            ERC20Like(asset).transferFrom(msg.sender, address(this), amount),
            "Conduit/transfer-failed"
        );

        positions[msg.sender][asset] += amount;
        totalPositions[asset]        += amount;
    }

    function withdraw(address asset, uint256 amount) external isRouter {
        require(
            ERC20Like(asset).transfer(msg.sender, amount),
            "Conduit/transfer-failed"
        );

        positions[msg.sender][asset] -= amount;
        totalPositions[asset]        -= amount;
    }

    function isCancelable(uint256 fundRequestId) external view returns (bool isCancelable_) {}

    function requestFunds(uint256 amount) external returns (uint256 fundRequestId) {}

    function cancelFundRequest(uint256 fundRequestId) external {}

    function withdraw(uint256 fundRequestId) external returns (uint256 resultingFundRequestId) {}

    function withdrawStatus(uint256 withdrawId) external returns (address owner, uint256 amount, StatusEnum status) {}

    function activeWithdraws(address owner) external returns (uint256[] memory withdrawIds, uint256 totalAmount) {}

    function totalActiveWithdraws() external returns (uint256 totalAmount) {}

}
