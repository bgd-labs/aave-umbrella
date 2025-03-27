import "invariants.spec";





// ======================================================================================
// Rule: integrity_of_deposit
// Description: We check that when the deposit(...) function is called the following holds:
//            - The balances of the involved users and currentContract is as expected.
//            - The totalAssets() is updated as expected
// Status: PASS
// ======================================================================================
rule integrity_of_deposit(address reciever, uint256 amount_of_assets, env e) {
  require(asset() == stake_token);
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  require(e.msg.sender != currentContract);

  uint256 StakeToken_bal_depositor_before = stake_token.balanceOf(e.msg.sender);
  uint256 StakeToken_bal_vault_before = stake_token.balanceOf(currentContract);
  uint256 bal_reciever_before = balanceOf(reciever);
  uint256 total_assets_before = totalAssets();
  uint256 shares = previewDeposit(e,amount_of_assets);
  
  deposit(e, amount_of_assets, reciever);

  uint256 StakeToken_bal_depositor_after = stake_token.balanceOf(e.msg.sender);
  uint256 StakeToken_bal_vault_after = stake_token.balanceOf(currentContract);
  uint256 total_assets_after = totalAssets();
  uint256 bal_reciever_after = balanceOf(reciever);
  
  assert StakeToken_bal_depositor_after == StakeToken_bal_depositor_before - amount_of_assets;
  assert StakeToken_bal_vault_after == StakeToken_bal_vault_before + amount_of_assets;
  assert total_assets_after == total_assets_before + amount_of_assets;
  assert bal_reciever_after == bal_reciever_before + shares;
}


// ======================================================================================
// Rule: integrity_of_mint
// Description: We check that when the mint(...) function is called the following holds:
//            - The balances of the involved users and currentContract is as expected.
//            - The totalAssets() is updated as expected
// Status: PASS
// ======================================================================================
rule integrity_of_mint(address reciever, uint256 amount_of_shares, env e) {
  require(asset() == stake_token);
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  require(e.msg.sender != currentContract);

  uint256 StakeToken_bal_depositor_before = stake_token.balanceOf(e.msg.sender);
  uint256 StakeToken_bal_vault_before = stake_token.balanceOf(currentContract);
  uint256 bal_reciever_before = balanceOf(reciever);
  uint256 total_assets_before = totalAssets();
  uint256 assets = previewMint(e,amount_of_shares);
  
  mint(e, amount_of_shares, reciever);

  uint256 StakeToken_bal_depositor_after = stake_token.balanceOf(e.msg.sender);
  uint256 StakeToken_bal_vault_after = stake_token.balanceOf(currentContract);
  uint256 bal_reciever_after = balanceOf(reciever);
  uint256 total_assets_after = totalAssets();
  
  assert StakeToken_bal_depositor_after == StakeToken_bal_depositor_before - assets;
  assert StakeToken_bal_vault_after == StakeToken_bal_vault_before + assets;
  assert bal_reciever_after == bal_reciever_before + amount_of_shares;
  assert total_assets_after == total_assets_before + assets;
}


// ======================================================================================
// Rule: integrity_of_withdraw
// Description: We check that when the withdraw(...) function is called the following holds:
//            - The balances of the involved users and currentContract is as expected.
//            - The totalAssets() is updated as expected
//            - The withdraw is indeed possible according to the cooldown info
//            - The Cooldown amount is indeed updated as expected.
// Status: PASS
// ======================================================================================
rule integrity_of_withdraw(env e, uint256 amount_of_assets, address reciever, address owner) {
  require asset() == stake_token;
  require e.block.timestamp > 0;
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  requireInvariant cooldown_data_correctness(owner);

  uint256 StakeToken_bal_reciever_before = stake_token.balanceOf(reciever);
  uint256 StakeToken_bal_vault_before = stake_token.balanceOf(currentContract);
  uint256 bal_owner_before = balanceOf(owner);
  uint256 total_assets_before = totalAssets();
  
  uint32 owner_endOfCooldown = cooldownEndOfCooldown(owner);
  uint32 owner_withdrawalWindow = cooldownWithdrawalWindow(owner);
  uint192 owner_cooldownAmount_before = cooldownAmount(owner);
  
  uint256 shares = withdraw(e, amount_of_assets, reciever, owner);

  uint256 StakeToken_bal_reciever_after = stake_token.balanceOf(reciever);
  uint256 StakeToken_bal_vault_after = stake_token.balanceOf(currentContract);
  uint256 bal_owner_after = balanceOf(owner);
  uint256 total_assets_after = totalAssets();
  uint192 owner_cooldownAmount_after = cooldownAmount(owner);
  
  assert currentContract != reciever ?
    StakeToken_bal_reciever_after == StakeToken_bal_reciever_before + amount_of_assets :
    StakeToken_bal_reciever_after == StakeToken_bal_reciever_before;
  assert currentContract != reciever ?
    StakeToken_bal_vault_after == StakeToken_bal_vault_before - amount_of_assets :
    StakeToken_bal_vault_after == StakeToken_bal_vault_before;
  assert bal_owner_after == bal_owner_before - shares;
  assert total_assets_after == total_assets_before - amount_of_assets;

  assert shares > 0 =>
    owner_endOfCooldown <= e.block.timestamp && e.block.timestamp <= owner_endOfCooldown + owner_withdrawalWindow;
  assert shares <= owner_cooldownAmount_before;
  assert owner_cooldownAmount_after == owner_cooldownAmount_before - shares;
}


// ======================================================================================
// Rule: integrity_of_redeem
// Description: We check that when the redeem(...) function is called the following holds:
//            - The balances of the involved users and currentContract is as expected.
//            - The totalAssets() is updated as expected
//            - The withdraw is indeed possible according to the cooldown info
//            - The Cooldown amount is indeed updated as expected.
// Status: PASS
// ======================================================================================
rule integrity_of_redeem(env e, uint256 amount_of_shares, address reciever, address owner) {
  require (asset() == stake_token);
  require (currentContract != owner);
  require e.block.timestamp > 0;
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  requireInvariant cooldown_data_correctness(owner);

  uint256 StakeToken_bal_reciever_before = stake_token.balanceOf(reciever);
  uint256 StakeToken_bal_vault_before = stake_token.balanceOf(currentContract);
  uint256 bal_owner_before = balanceOf(owner);
  uint256 total_assets_before = totalAssets();

  uint32 owner_endOfCooldown = cooldownEndOfCooldown(owner);
  uint32 owner_withdrawalWindow = cooldownWithdrawalWindow(owner);
  uint192 owner_cooldownAmount_before = cooldownAmount(owner);
  
  uint256 assets = redeem(e, amount_of_shares, reciever, owner);
  
  uint256 StakeToken_bal_reciever_after = stake_token.balanceOf(reciever);
  uint256 StakeToken_bal_vault_after = stake_token.balanceOf(currentContract);
  uint256 bal_owner_after = balanceOf(owner);
  uint256 total_assets_after = totalAssets();
  uint192 owner_cooldownAmount_after = cooldownAmount(owner);
  
  assert currentContract != reciever ?
    StakeToken_bal_reciever_after == StakeToken_bal_reciever_before + assets:
    StakeToken_bal_reciever_after == StakeToken_bal_reciever_before;
  assert currentContract != reciever ?
    StakeToken_bal_vault_after == StakeToken_bal_vault_before - assets :
    StakeToken_bal_vault_after == StakeToken_bal_vault_before;
  assert bal_owner_after == bal_owner_before - amount_of_shares;
  assert total_assets_after == total_assets_before - assets;

  assert amount_of_shares > 0 =>
    owner_endOfCooldown <= e.block.timestamp && e.block.timestamp <= owner_endOfCooldown + owner_withdrawalWindow;
  assert amount_of_shares <= owner_cooldownAmount_before;
  assert owner_cooldownAmount_after == owner_cooldownAmount_before - amount_of_shares;
}



// ======================================================================================
// Rule: integrity_of_slashing
// Description: We check that when the slash(...) function is called the following holds:
//            - The balances of currentContract and the destination are as expected.
//            - The totalAssets() is updated as expected
//            - The slashing amount doesn't exceed get_maxSlashable().
// Status: PASS
// ======================================================================================
rule integrity_of_slashing(env e, address dest, uint256 amount) {
  require(asset() == stake_token);
  require(currentContract != e.msg.sender);
  requireInvariant inv_sumOfBalances_eq_totalSupply();

  uint256 StakeToken_bal_dest_before = stake_token.balanceOf(dest);
  uint256 StakeToken_bal_vault_before = stake_token.balanceOf(currentContract);
  uint256 total_assets_before = totalAssets();
  
  // We calculate maxSlashable the same way it is calculated in slash(...)
  mathint maxSlashable = get_maxSlashable();
  slash(e, dest, amount);
  
  uint256 StakeToken_bal_dest_after = stake_token.balanceOf(dest);
  uint256 StakeToken_bal_vault_after = stake_token.balanceOf(currentContract);
  uint256 total_assets_after = totalAssets();
  
  mathint amountToSlash;
  if (amount > maxSlashable) {
    amountToSlash = maxSlashable;
  } else {
    amountToSlash = amount;
  }
  
  assert currentContract != dest ?
    StakeToken_bal_vault_after == StakeToken_bal_vault_before - amountToSlash:
    StakeToken_bal_vault_after == StakeToken_bal_vault_before;
  assert currentContract != dest ?
    StakeToken_bal_dest_after == StakeToken_bal_dest_before + amountToSlash :
    StakeToken_bal_dest_after == StakeToken_bal_dest_before;
  assert currentContract != dest ?
    total_assets_after == total_assets_before - amountToSlash :
    true;
  //    total_assets_after == total_assets_before;
}


// ======================================================================================
// Rule: cooldown_always_updates_cooldown_info
// Description: We check that when after calling to cooldown the relevant information
//              get updated as expected.
// Status: PASS
// ======================================================================================
rule cooldown_always_updates_cooldown_info() {
    env e;
    uint40 block_timestamp = require_uint40(e.block.timestamp);
    cooldown(e);
    
    assert cooldownEndOfCooldown(e.msg.sender)==block_timestamp + getCooldown();
    assert (assert_uint256(cooldownAmount(e.msg.sender))==balanceOf(e.msg.sender));
}



// ======================================================================================
// Rule: integrity_of_transferFrom
// Description: We check that when the transferFrom(...) function is called the following holds:
//            - The balances of the involved users and currentContract is as expected.
//            - The totalAssets() remains unchanged
//            - The cooldown amounts of the sender and the reciever is as expected.
// Status: PASS
// ======================================================================================
rule integrity_of_transferFrom(env e, address from, address to, uint256 value) {
  require (asset() == stake_token);
  require e.block.timestamp > 0;
  requireInvariant inv_sumOfBalances_eq_totalSupply();

  uint256 StakeToken_bal_from_before = stake_token.balanceOf(from);
  uint256 StakeToken_bal_to_before = stake_token.balanceOf(to);
  uint256 StakeToken_bal_vault_before = stake_token.balanceOf(currentContract);
  uint256 bal_from_before = balanceOf(from);
  uint256 bal_to_before = balanceOf(to);
  uint256 total_assets_before = totalAssets();

  uint32 from_endOfCooldown = cooldownEndOfCooldown(from);
  uint32 from_withdrawalWindow = cooldownWithdrawalWindow(from);
  // the field endOfCooldown is sampled from the time-stamp hence if a user calls to cooldown(), it can't be 0.
  require from_withdrawalWindow>0 => from_endOfCooldown>0; 
  uint192 from_cooldownAmount_before = cooldownAmount(from);
  uint192 to_cooldownAmount_before = cooldownAmount(to);
  
  transferFrom(e, from, to, value);
  
  uint256 StakeToken_bal_from_after = stake_token.balanceOf(from);
  uint256 StakeToken_bal_to_after = stake_token.balanceOf(to);
  uint256 StakeToken_bal_vault_after = stake_token.balanceOf(currentContract);
  uint256 bal_from_after = balanceOf(from);
  uint256 bal_to_after = balanceOf(to);
  uint256 total_assets_after = totalAssets();
  
  uint192 from_cooldownAmount_after = cooldownAmount(from);
  uint192 to_cooldownAmount_after = cooldownAmount(to);

  assert StakeToken_bal_from_after == StakeToken_bal_from_before;
  assert StakeToken_bal_to_after == StakeToken_bal_to_before;
  assert StakeToken_bal_vault_after == StakeToken_bal_vault_before;
  assert total_assets_after == total_assets_before;
  assert from!=to => (bal_from_after == bal_from_before - value && bal_to_after == bal_to_before + value);
  assert from==to => bal_from_after == bal_from_before;

  assert from!=to => to_cooldownAmount_after == to_cooldownAmount_before;
  assert (from!=to && bal_from_after < from_cooldownAmount_before && in_withdrawal_window(e,from)) =>
    from_cooldownAmount_after == bal_from_after;
}


// ======================================================================================
// Rule: Bob_cant_harm_Alice
// Description: The balance of Alice can't be badly affected by any operation of Bob.
// Status: PASS
// ======================================================================================
rule Bob_cant_harm_Alice (method f)
  filtered {f -> !f.isView && f.contract == currentContract && !is_admin_func(f)}
{
  address Alice;
  env e2; address Bob = e2.msg.sender;
  
  require Alice != Bob; require Alice != currentContract; require Bob != currentContract;
  require (allowance(Alice, Bob)==0);
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  
  uint256 Alice_bal_1 = balanceOf(Alice);

  calldataarg args;
  f(e2, args);

  uint256 Alice_bal_2 = balanceOf(Alice);
  assert Alice_bal_1 <= Alice_bal_2;
}


// ======================================================================================
// Rule: calling_to_handleAction
// Description: We check that the function handleAction() (of the rewards_controller) is
//              called in the following cases:
//            - The balance of a user was changed
//            - totalAssets() was changed
// Status: PASS
// ======================================================================================
rule calling_to_handleAction(env e, address bob) {
  require (asset() == stake_token);

  handleAction_was_called = false;
  handleAction_user1 = 0;
  handleAction_user2 = 0;

  uint256 bal_bob_before = balanceOf(bob);
  uint256 total_assets_before = totalAssets();

  method f; calldataarg args;
  f(e,args);
  
  uint256 bal_bob_after = balanceOf(bob);
  uint256 total_assets_after = totalAssets();

  assert (bal_bob_after != bal_bob_before) =>
    (handleAction_was_called==true && (handleAction_user1==bob || handleAction_user2==bob));
  assert (total_assets_after != total_assets_before) => (handleAction_was_called==true);
}


// ======================================================================================
// Rule: only_admin_can_call_adminFuncs
// Description: We check that indeed all the functions that are specified in "is_admin_func"
//              can only be called by the admin (owner())               
// Status: PASS
// ======================================================================================
rule only_admin_can_call_adminFuncs(method f, env e)
  filtered {f -> is_admin_func(f)}
{
  calldataarg args;
  f(e,args);
  assert e.msg.sender == owner();
}


// ======================================================================================
// Rule: Bob_cant_DOS_Alice__redeem
// Description: Any action from Bob side can prevent from alice to perform redeem.
// Assumptios: We assume that the totalSupply of the stake_token and of the currentContract
//             doesn't exceed 10^33 (to prevent reverts due to overflow)
// Status: PASS
// ======================================================================================
rule Bob_cant_DOS_Alice__redeem (method f)
  filtered {f ->
    !f.isView
    && f.contract == currentContract
    && !is_admin_func(f)
    && f.selector != sig:cooldownWithPermit(address,uint256,IERC4626StakeToken.SignatureParams).selector
    && f.selector != sig:initialize(address,string,string,address,uint256,uint256).selector
    }
{
  require(asset() == stake_token);
  requireInvariant inv_sumOfBalances_eq_totalSupply();  require totalSupply() <= 10^33;
  requireInvariant inv_sumOfBalances_eq_totalSupply__stake_token(); require stake_token.totalSupply() <= 10^33;
  requireInvariant calculated_bal_LEQ_real_bal();

  env e1; address Alice = e1.msg.sender;
  env e2; address Bob = e2.msg.sender;
  require e2.block.timestamp <= e1.block.timestamp;

  require Alice != Bob; require Alice != currentContract; require Bob != currentContract;
  require allowance(Alice, Bob)==0;
  require isCooldownOperator(Alice,Bob)==false; 
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  
  storage initialStorage = lastStorage;

  uint256 amount_of_shares;
  redeem(e1, amount_of_shares, Alice, Alice);

  // Now we start it all over, and let bob to call some function before alice claims her rewards
  calldataarg args;
  f(e2, args) at initialStorage; // bob do something

  redeem@withrevert(e1, amount_of_shares, Alice, Alice);
  assert !lastReverted;
}



// ======================================================================================
// Rule: only_slash_can_decrease_the_shares_worth
// Description: The only way to that the worth of a share can be decreased is by calling to slash
// Status: PASS
// ======================================================================================
rule only_slash_can_decrease_the_shares_worth(method f)
  filtered {f ->
    !f.isView
    && f.contract == currentContract
    }
{
  require(asset() == stake_token);
  requireInvariant inv_sumOfBalances_eq_totalSupply();  require totalSupply() <= 10^33;
  requireInvariant inv_sumOfBalances_eq_totalSupply__stake_token(); require stake_token.totalSupply() <= 10^33;
  requireInvariant calculated_bal_LEQ_real_bal();

  env e;
  uint amount_of_shares;
  uint amount_of_assets_pre = previewRedeem(amount_of_shares);

  calldataarg args; f(e, args);
 
  uint amount_of_assets_post = previewRedeem(amount_of_shares);

  assert amount_of_assets_post < amount_of_assets_pre => f.selector == sig:slash(address,uint256).selector;
}


// ======================================================================================
// Rule: slash_respects_MIN_ASSETS_REMAINING
// Description: After slashing the amount of assets must be at least MIN_ASSETS_REMAINING.
// Status: PASS
// ======================================================================================
rule slash_respects_MIN_ASSETS_REMAINING() {
  require(asset() == stake_token);
  requireInvariant inv_sumOfBalances_eq_totalSupply();  require totalSupply() <= 10^33;
  requireInvariant inv_sumOfBalances_eq_totalSupply__stake_token(); require stake_token.totalSupply() <= 10^33;
  requireInvariant calculated_bal_LEQ_real_bal();

  env e; address dest; uint256 amount;
  slash(e, dest, amount);
  
  assert totalAssets() >= MIN_ASSETS_REMAINING();
}


// ======================================================================================
// Rule: setCooldown_doesnt_affect_ongoing_cooldowns
// Description: When the admin call to setCooldown(newCooldown), it doesn't affect an on-going
//              cooldown.
// Note: we check the above by verifying the following: If Alice is able to perform redeem at
//       some timestamp, then she whould be able to perform that redeem (and get the same
//       amount of assets) even if setCooldown() was called before the redeem.
// Note: While we proved that setCooldown(..) doesn't affect on-going cooldowns, setUnstakeWindow(..)
//       does affect on-going cooldowns.
// Status: PASS
// ======================================================================================
rule setCooldown_doesnt_affect_ongoing_cooldowns() {
  require(asset() == stake_token);
  requireInvariant inv_sumOfBalances_eq_totalSupply();  require totalSupply() <= 10^33;
  requireInvariant inv_sumOfBalances_eq_totalSupply__stake_token(); require stake_token.totalSupply() <= 10^33;
  requireInvariant calculated_bal_LEQ_real_bal();
  
  env e1; address Alice = e1.msg.sender;
  env e2; address Bob = e2.msg.sender;
  require e2.block.timestamp <= e1.block.timestamp;

  require Alice != currentContract;
  requireInvariant inv_sumOfBalances_eq_totalSupply();
  
  storage initialStorage = lastStorage;

  uint256 amount;
  uint256 amount_of_asset_pre = redeem(e1, amount, Alice, Alice);

  // Now we start it all over, and let the admin set a new cooldown
  uint256 newCooldown; 
  setCooldown(e2,newCooldown) at initialStorage;

  uint256 amount_of_asset_post = redeem@withrevert(e1, amount, Alice, Alice);
  assert !lastReverted;
  assert amount_of_asset_post==amount_of_asset_pre;
}

