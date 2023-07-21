// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "../../lib/mock-erc20/src/MockERC20.sol";

contract RevertingERC20 is MockERC20 {

    constructor(string memory name, string memory symbol, uint8 decimals)
        MockERC20(name, symbol, decimals) {}

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }

}
