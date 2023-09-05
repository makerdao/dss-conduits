// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IArrangerHandlerLike {

    function drawnFunds(address asset) external view returns (uint256 drawnFunds_);

    function returnedFunds(address asset) external view returns (uint256 returnedFunds_);

}

interface ITransfererHandlerLike {

    function transferredFunds(address asset) external view returns (uint256 transferredFunds_);

}
