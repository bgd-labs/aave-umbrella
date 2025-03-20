import "setup.spec";




//================================================================================================
// Rule: pending_deficit_cant_exceed_real_deficit
// Description: Any operation of currentContract cant make the pending-deficit bigger than the real-deficit
// Status: PASS
//================================================================================================
invariant pending_deficit_cant_exceed_real_deficit(address reserve)
  getReserveDeficitCVL(reserve) >= getPendingDeficit(reserve)
filtered {f -> f.contract == currentContract}





ghost mathint sumOfBalances_erc20A {
    init_state axiom sumOfBalances_erc20A == 0;
}
hook Sstore ERC20A._balances[KEY address account] uint256 balance (uint256 balance_old) {
  sumOfBalances_erc20A = sumOfBalances_erc20A + balance - balance_old;
}
hook Sload uint256 balance ERC20A._balances[KEY address account] {
  require balance <= sumOfBalances_erc20A;
}

// ====================================================================
// Invariant: inv_sumOfBalances_eq_totalSupply__erc20A
// Description: The total supply equals the sum of all users' balances.
// Status: PASS
// ====================================================================
invariant inv_sumOfBalances_eq_totalSupply__erc20A()
  sumOfBalances_erc20A == erc20A.totalSupply();

ghost mathint sumOfBalances_erc20B {
    init_state axiom sumOfBalances_erc20B == 0;
}
hook Sstore ERC20B._balances[KEY address account] uint256 balance (uint256 balance_old) {
  sumOfBalances_erc20B = sumOfBalances_erc20B + balance - balance_old;
}
hook Sload uint256 balance ERC20B._balances[KEY address account] {
  require balance <= sumOfBalances_erc20B;
}

// ====================================================================
// Invariant: inv_sumOfBalances_eq_totalSupply__erc20B
// Description: The total supply equals the sum of all users' balances.
// Status: PASS
// ====================================================================
invariant inv_sumOfBalances_eq_totalSupply__erc20B()
  sumOfBalances_erc20B == erc20B.totalSupply();



