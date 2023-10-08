// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { InvariantTestBase } from "./InvariantTestBase.t.sol";

import { ArrangerBase, ArrangerBounded }     from "./handlers/Arranger.sol";
import { OperatorBase, OperatorBounded }     from "./handlers/Operator.sol";
import { TransfererBase, TransfererBounded } from "./handlers/Transferer.sol";

// These invariants assume external transfers into the contract, so balance-based
// invariants are asserted with with gt/lt checks
contract InvariantTest is InvariantTestBase {

    function setUp() public override {
        super.setUp();

        // Get string from env and hash for comparison
        bytes32 foundryProfile
            = keccak256(abi.encodePacked(vm.envOr("FOUNDRY_PROFILE", string(""))));

        address conduit_ = address(conduit);

        // Set up testing suite with bounded handlers unless otherwise specified.
        // This is necessary because unbounded testing requires specific env configuration.
        if (
            foundryProfile == keccak256(abi.encodePacked("unbounded")) ||
            foundryProfile == keccak256(abi.encodePacked("unbounded-ci"))
        ) {
            arrangerHandler   = address(new ArrangerBase(conduit_, address(this)));
            operatorHandler1  = address(new OperatorBase(conduit_, ilks[0], address(this)));
            operatorHandler2  = address(new OperatorBase(conduit_, ilks[1], address(this)));
            operatorHandler3  = address(new OperatorBase(conduit_, ilks[2], address(this)));
            transfererHandler = address(new TransfererBase(conduit_, address(this)));
        } else {
            arrangerHandler   = address(new ArrangerBounded(conduit_, address(this)));
            operatorHandler1  = address(new OperatorBounded(conduit_, ilks[0], address(this)));
            operatorHandler2  = address(new OperatorBounded(conduit_, ilks[1], address(this)));
            operatorHandler3  = address(new OperatorBounded(conduit_, ilks[2], address(this)));
            transfererHandler = address(new TransfererBounded(conduit_, address(this)));
        }

        super.configureHandlers();
    }

    function invariant_A_B_C_D() external { assert_invariant_A_B_C_D(); }
    function invariant_E()       external { assert_invariant_E(); }
    function invariant_F()       external { assert_invariant_F(); }
    function invariant_G()       external { assert_invariant_G(); }
    function invariant_H()       external { assert_invariant_H(); }

}

