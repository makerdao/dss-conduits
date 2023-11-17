// ArrangerConduit.spec

using GemMock as gem;

methods {
    function wards(address) external returns (uint256) envfree;

    //function gem.allowance(address, address) external returns (uint256) envfree; // TODO: do we need this
    //function _.approve(address, uint256) external => DISPATCHER(true) UNRESOLVED; // TODO: do we need this

    function _.transfer(address, uint256) external => DISPATCHER(true) UNRESOLVED;
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true) UNRESOLVED;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;

    mathint wardsBefore = wards(anyAddr);

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);

    assert wardsAfter != wardsBefore => f.selector == sig:UpgradeableProxy.rely(address).selector || f.selector == sig:UpgradeableProxy.deny(address).selector, "wards[x] changed in an unexpected function";
}

/*

// Verify correct storage changes for non reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    rely(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 1, "rely did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "rely did not keep unchanged the rest of wards[x]";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    deny(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 0, "deny did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "deny did not keep unchanged the rest of wards[x]";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting approve
rule approve(address asset, address spender, uint256 amount) {
    env e;

    require asset == gem;

    approve(e, asset, spender, amount);

    mathint allowance = gem.allowance(currentContract, spender);

    assert allowance == to_mathint(amount), "approve did not set allowance to amount value";
}

// Verify revert rules on approve
rule approve_revert(address asset, address spender, uint256 amount) {
    env e;

    require asset == gem;

    mathint wardsSender = wards(e.msg.sender);

    approve@withrevert(e, asset, spender, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}
*/
