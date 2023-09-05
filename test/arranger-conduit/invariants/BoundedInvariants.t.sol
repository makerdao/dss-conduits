// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { InvariantTestBase } from "./InvariantTestBase.t.sol";

import { ArrangerBounded }   from "./handlers/Arranger.sol";
import { OperatorBounded }   from "./handlers/Operator.sol";
import { TransfererBounded } from "./handlers/Transferer.sol";

// These invariants assume external transfers into the contract, so balance-based
// invariants are asserted with with gt/lt checks
contract BoundedInvariants is InvariantTestBase {

    // TODO: Move to base
    address public arrangerHandler;
    address public operatorHandler1;
    address public operatorHandler2;
    address public operatorHandler3;
    address public transfererHandler;

    function setUp() public override {
        arrangerHandler   = address(new ArrangerBounded(address(conduit), address(this)));
        operatorHandler1  = address(new OperatorBounded(address(conduit), ilks[0], address(this)));
        operatorHandler2  = address(new OperatorBounded(address(conduit), ilks[1], address(this)));
        operatorHandler3  = address(new OperatorBounded(address(conduit), ilks[2], address(this)));
        transfererHandler = address(new TransfererBounded(address(conduit), address(this)));

        // TODO: This is temporary
        _setupOperatorRole(ilks[0], operatorHandler1);
        _setupOperatorRole(ilks[1], operatorHandler2);
        _setupOperatorRole(ilks[2], operatorHandler3);

        conduit.file("arranger", arrangerHandler);
        conduit.file("registry", address(registry));
        conduit.file("roles",    address(roles));

        // NOTE: Buffer == operator here, should change with broader integration testing
        registry.file(ilks[0], "buffer", operatorHandler1);
        registry.file(ilks[1], "buffer", operatorHandler2);
        registry.file(ilks[2], "buffer", operatorHandler3);

        targetContract(arrangerHandler);
        targetContract(operatorHandler1);
        targetContract(operatorHandler2);
        targetContract(operatorHandler3);
        targetContract(transfererHandler);
    }

}

