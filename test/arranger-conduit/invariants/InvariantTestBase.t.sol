// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "../../../lib/forge-std/src/Test.sol";

import { AllocatorRegistry } from "../../../lib/dss-allocator/src/AllocatorRegistry.sol";
import { AllocatorRoles }    from "../../../lib/dss-allocator/src/AllocatorRoles.sol";

import { MockERC20 } from "../../../lib/mock-erc20/src/MockERC20.sol";

import { UpgradeableProxy } from "../../../lib/upgradeable-proxy/src/UpgradeableProxy.sol";

import { ArrangerConduit } from "../../../src/ArrangerConduit.sol";

import { OperatorHandlerBoundedBase } from "./handlers/Operator.sol";

contract InvariantTestBase is Test {

    uint8 ROLE = 0;

    address[] public assets;

    bytes32[] public ilks;

    ArrangerConduit public conduit;

    OperatorHandlerBoundedBase public operatorHandler;

    AllocatorRegistry public registry              = new AllocatorRegistry();
    AllocatorRoles    public roles                 = new AllocatorRoles();
    ArrangerConduit   public conduitImplementation = new ArrangerConduit();
    UpgradeableProxy  public conduitProxy          = new UpgradeableProxy();

    function setUp() external {
        conduitProxy.setImplementation(address(conduitImplementation));

        conduit = ArrangerConduit(address(conduitProxy));

        operatorHandler = new OperatorHandlerBoundedBase(address(conduit), address(this));

        // TODO: temporary
        _addAsset();
        _addIlk();

        // TODO: This is temporary
        _setupOperatorRole(ilks[0], address(operatorHandler));

        // conduit.file("arranger", arranger); TODO: Use handler
        conduit.file("registry", address(registry));
        conduit.file("roles",    address(roles));

        // NOTE: Buffer == operator here, should change with broader integration testing
        registry.file(ilks[0], "buffer", address(operatorHandler));

        targetContract(address(operatorHandler));
    }

    /**********************************************************************************************/
    /*** Invariants                                                                             ***/
    /**********************************************************************************************/

    function invariant_A() external {
        assertTrue(true);
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function getAssetsLength() public view returns (uint256) {
        return assets.length;
    }

    function getIlksLength() public view returns (uint256) {
        return ilks.length;
    }

    /**********************************************************************************************/
    /*** Utility Functions                                                                      ***/
    /**********************************************************************************************/

    function _addAsset() internal {
        assets.push(address(new MockERC20("asset", "ASSET", 18)));
    }

    function _addIlk() internal {
        ilks.push(bytes32(abi.encode("ilk", ilks.length)));
    }

    function _setupOperatorRole(bytes32 ilk_, address operator_) internal {
        // Ensure address(this) can always set for a new ilk
        roles.setIlkAdmin(ilk_, address(this));

        roles.setUserRole(ilk_, operator_, ROLE, true);

        address conduit_ = address(conduit);

        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.deposit.selector,           true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.withdraw.selector,          true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.requestFunds.selector,      true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.cancelFundRequest.selector, true);
    }

}
