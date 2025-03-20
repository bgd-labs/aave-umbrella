using DummyERC20Impl as stake_token;

methods {
  function stake_token.balanceOf(address) external returns (uint256) envfree;
  function stake_token.totalSupply() external returns (uint256) envfree;

  function balanceOf(address) external returns (uint256) envfree;
  function totalSupply() external returns (uint256) envfree;
  function totalAssets() external returns (uint256) envfree;
  function previewRedeem(uint256) external returns (uint256) envfree;
  function get_maxSlashable() external returns (uint256) envfree;
  function getCooldown() external returns (uint256) envfree;
  function getUnstakeWindow() external returns (uint256) envfree;
  function cooldownAmount(address) external returns (uint192) envfree;
  function cooldownEndOfCooldown(address) external returns (uint32) envfree;
  function cooldownWithdrawalWindow(address user) external returns (uint32) envfree;
  function paused() external returns (bool) envfree;
  function asset() external returns (address) envfree;
  function stake_token.balanceOf(address) external returns (uint256) envfree;
  function maxRescue(address erc20Token) external returns (uint256) envfree;
  function allowance(address owner, address spender) external returns (uint256) envfree;
  function owner() external returns (address) envfree;
  function isCooldownOperator(address user, address operator) external returns (bool) envfree;
  function previewRedeem(uint256 shares) external returns (uint256) envfree;
  function MIN_ASSETS_REMAINING() external returns (uint256) envfree;
}

methods {
  function _.handleAction(uint256 totalSupply, uint256 totalAssets, address user, uint256 userBalance) external
    => handleActionCVL(user) expect void;

  function _.permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external => NONDET;
  function _.permit(address, address, uint256, uint256, uint8, bytes32, bytes32) internal => NONDET;
  
// ==============================================================================================
// NOTE: in our setup the contract DummyERC20Impl(stake_token) is the staked-asset. We want that the following 
// dispatchers will eventually call the functions of DummyERC20Impl (in case of non-resolved calls
// of course). To ensure that, at the beginning of all the rules and invariants we do:
//     require(asset() == stake_token);
// (asset() returns the staked-asset)
// ==============================================================================================
  function _.transfer(address to, uint256 value) external => DISPATCHER(true);
  function _.transferFrom(address from, address to, uint256 value) external => DISPATCHER(true);
  function _.safeTransfer(address to, uint256 value) external => DISPATCHER(true);
  function _.safeTransferFrom(address from, address to, uint256 value) external => DISPATCHER(true);
  function _.balanceOf(address usr) external => DISPATCHER(true);
  function _.decimals() external => DISPATCHER(true);

  function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDiv_CVL(x,y,denominator)  expect (uint256);
  function _.mulDiv(uint256 x, uint256 y, uint256 denominator) external => mulDiv_CVL(x,y,denominator)  expect (uint256);
}

function mulDiv_CVL(mathint x, mathint y, mathint denominator) returns uint256 {
  uint256 ret = require_uint256 (x*y/denominator);
  return ret;
}

definition is_admin_func(method f) returns bool =
  f.selector == sig:slash(address,uint256).selector
  || f.selector == sig:pause().selector
  || f.selector == sig:unpause().selector
  || f.selector == sig:setUnstakeWindow(uint256).selector
  || f.selector == sig:setCooldown(uint256).selector
    ;

function in_withdrawal_window(env e, address user) returns bool {
  return
    cooldownEndOfCooldown(user) <= e.block.timestamp &&
    e.block.timestamp <= cooldownEndOfCooldown(user) + cooldownWithdrawalWindow(user);
}

ghost bool handleAction_was_called;
ghost address handleAction_user1;
ghost address handleAction_user2;
function handleActionCVL(address user) {
  if (!handleAction_was_called) {
    handleAction_was_called = true;
    handleAction_user1 = user;
  }
  else {
    // we come here only if it's not the first call to handleAction(...)
    handleAction_user2 = user;
  }
}
