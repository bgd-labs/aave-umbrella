import "base.spec";


/* ==================================
                          104
         32      64      96|
         |       |       | |           
0x123456789012345678901234567890
=================================== */

ghost mathint sumOfBalances {
    init_state axiom sumOfBalances == 0;
}
hook Sstore UmbrellaStakeTokenHarness.(slot 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00).(offset 0)
[KEY address account] uint256 balance (uint256 balance_old) {
  sumOfBalances = sumOfBalances + balance - balance_old;
}
hook Sload uint256 balance UmbrellaStakeTokenHarness.(slot 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00).(offset 0)
[KEY address account] {
  require balance <= sumOfBalances;
}

// ====================================================================
// Invariant: inv_sumOfBalances_eq_totalSupply
// Description: The total supply equals the sum of all users' balances.
// Status: PASS
// ====================================================================
invariant inv_sumOfBalances_eq_totalSupply()
  sumOfBalances == totalSupply();



ghost mathint sumOfBalances_stake_token {
    init_state axiom sumOfBalances_stake_token == 0;
}
hook Sstore stake_token.b[KEY address a] uint256 balance (uint256 old_balance) {
    sumOfBalances_stake_token = sumOfBalances_stake_token - old_balance + balance;
}
hook Sload uint256 balance stake_token.b[KEY address a] {
    require balance <= sumOfBalances_stake_token;
}

// ======================================================================================
// Invariant: inv_sumOfBalances_eq_totalSupply__stake_token
// Description: The total supply of the staked-token equals the sum of all users' balances.
// Status: PASS
// ======================================================================================
invariant inv_sumOfBalances_eq_totalSupply__stake_token()
  sumOfBalances_stake_token == stake_token.totalSupply();



// ======================================================================================
// Invariant: total_supply_GEQ_user_bal
// Description: The total supply amount of shares is greater or equal to any user's share balance.
// Status: PASS
// ======================================================================================
invariant total_supply_GEQ_user_bal(address user)
    totalSupply() >= balanceOf(user)
{
    preserved {
        requireInvariant inv_sumOfBalances_eq_totalSupply();
    }
}


// ======================================================================================
// Invariant: cooldown_data_correctness
// Description: When cooldown amount of user nonzero, the cooldown had to be triggered
// Status: PASS
// ======================================================================================
invariant cooldown_data_correctness(address user)
  (cooldownWithdrawalWindow(user) > 0 || cooldownAmount(user) > 0) => cooldownEndOfCooldown(user) > 0
  {
    preserved with (env e)
    {
      require e.block.timestamp > 0;
      require e.block.timestamp < 2^32;
    }
  }
/*  
invariant cooldown_data_correctness2(address user)
  cooldownWithdrawalWindow(user) > 0 => cooldownEndOfCooldown(user) > 0
  {
    preserved with (env e)
    {
      require e.block.timestamp > 0;
      require e.block.timestamp < 2^32;
    }
    }*/

// ======================================================================================
// Invariant cooldown_amount_not_greater_than_balance
// Description: No user can have greater cooldown amount than is their balance.
// Status: PASS
// ======================================================================================
invariant cooldown_amount_not_greater_than_balance(env e, address user) 
  in_withdrawal_window(e,user) => balanceOf(user) >= assert_uint256(cooldownAmount(user))
  {
    preserved with (env e2) {
      require e2.block.timestamp == e.block.timestamp;
      require(asset() == stake_token);
      requireInvariant cooldown_data_correctness(user);
      requireInvariant total_supply_GEQ_user_bal(user);
      requireInvariant inv_sumOfBalances_eq_totalSupply();
    }
  }



// ======================================================================================
// Invariant: calculated_bal_LEQ_real_bal
// Description: Virtual accounting which is (totalAssets()) is always <= the real balance of the contract
// Status: PASS
// ======================================================================================
invariant calculated_bal_LEQ_real_bal()
  totalAssets() <= stake_token.balanceOf(currentContract)
  filtered {f -> f.contract == currentContract 
    }
{
  preserved with (env e)
  {
    require(asset() == stake_token);
    require e.msg.sender != currentContract;
    requireInvariant inv_sumOfBalances_eq_totalSupply();
    requireInvariant inv_sumOfBalances_eq_totalSupply__stake_token();
  }
}



