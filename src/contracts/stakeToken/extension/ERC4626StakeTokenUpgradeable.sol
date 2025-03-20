// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC4626Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol';
import {Initializable} from 'openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC4626} from 'openzeppelin-contracts/contracts/interfaces/IERC4626.sol';

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

import {IRewardsController} from '../../rewards/interfaces/IRewardsController.sol';
import {IERC4626StakeToken} from '../interfaces/IERC4626StakeToken.sol';

/**
 * @title ERC4626StakeTokenUpgradeable
 * @notice Stake token extension, which allows reducing the amount of users' assets. In addition to this, it has a `handleAction` hook for reward calculation.
 * @dev ERC20 extension, so ERC20 initialization should be done by the children contract/s
 * @author BGD labs
 */
abstract contract ERC4626StakeTokenUpgradeable is
  Initializable,
  ERC4626Upgradeable,
  IERC4626StakeToken
{
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  /// @custom:storage-location erc7201:aave.storage.StakeToken
  struct ERC4626StakeTokenStorage {
    /// @notice User cooldown options
    mapping(address user => CooldownSnapshot cooldownSnapshot) _stakerCooldown;
    /// @notice Addresses capable of triggering `cooldown` instead of user
    mapping(address user => mapping(address operator => bool)) _cooldownOperator;
    /// @notice Nonces for cooldownWithPermit function
    mapping(address user => uint256) _cooldownNonces;
    /// @notice Cooldown duration
    uint32 _cooldown;
    /// @notice Time period during which funds can be withdrawn
    uint32 _unstakeWindow;
    /// @notice Virtual accounting of assets
    uint192 _totalAssets;
  }

  // keccak256(abi.encode(uint256(keccak256("aave.storage.ERC4626StakeToken")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant ERC4626StakeTokenStorageLocation =
    0x3b7d252e513ca0740d527649afeab4abf7cb6ef2e75cb52cd2b8721d21834600;

  function _getERC4626StakeTokenStorage()
    private
    pure
    returns (ERC4626StakeTokenStorage storage $)
  {
    assembly {
      $.slot := ERC4626StakeTokenStorageLocation
    }
  }

  uint256 public constant MIN_ASSETS_REMAINING = 1e6;

  IRewardsController public immutable REWARDS_CONTROLLER;

  constructor(IRewardsController rewardsController) {
    if (address(rewardsController) == address(0)) {
      revert ZeroAddress();
    }

    REWARDS_CONTROLLER = rewardsController;
  }

  function __ERC4626StakeTokenUpgradeable_init(
    IERC20 stakedToken,
    uint256 cooldown_,
    uint256 unstakeWindow_
  ) internal onlyInitializing {
    __ERC4626_init_unchained(stakedToken);

    __ERC4626StakeTokenUpgradeable_init_unchained(cooldown_, unstakeWindow_);
  }

  function __ERC4626StakeTokenUpgradeable_init_unchained(
    uint256 cooldown_,
    uint256 unstakeWindow_
  ) internal onlyInitializing {
    _setCooldown(cooldown_);
    _setUnstakeWindow(unstakeWindow_);
  }

  /// @inheritdoc IERC4626StakeToken
  function cooldown() external {
    _cooldown(_msgSender());
  }

  /// @inheritdoc IERC4626StakeToken
  function cooldownOnBehalfOf(address owner) external {
    if (!isCooldownOperator(owner, _msgSender())) {
      revert NotApprovedForCooldown(owner, _msgSender());
    }

    _cooldown(owner);
  }

  /// @inheritdoc IERC4626StakeToken
  function setCooldownOperator(address operator, bool flag) external {
    _setCooldownOperator(_msgSender(), operator, flag);
  }

  ///// @dev Methods requiring mandatory access control, because of it kept undefined

  /// @inheritdoc IERC4626StakeToken
  function slash(address destination, uint256 amount) external virtual returns (uint256);

  /// @inheritdoc IERC4626StakeToken
  function setUnstakeWindow(uint256 newUnstakeWindow) external virtual;

  /// @inheritdoc IERC4626StakeToken
  function setCooldown(uint256 newCooldown) external virtual;

  ///////////////////////////////////////////////////////////////////////////////////

  /// @inheritdoc IERC4626StakeToken
  function getMaxSlashableAssets() external view returns (uint256) {
    return _getMaxSlashableAssets();
  }

  /// @inheritdoc IERC4626StakeToken
  function cooldownNonces(address owner) external view returns (uint256) {
    return _getERC4626StakeTokenStorage()._cooldownNonces[owner];
  }

  /// @notice `maxWithdraw` amount is limited by the current `cooldown` snapshot status
  /// @inheritdoc IERC4626
  function maxWithdraw(
    address owner
  ) public view virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
    return _convertToAssets(maxRedeem(owner), Math.Rounding.Floor);
  }

  /// @notice `maxRedeem` amount is limited by the current `cooldown` snapshot status
  /// @inheritdoc IERC4626
  function maxRedeem(
    address owner
  ) public view virtual override(ERC4626Upgradeable, IERC4626) returns (uint256) {
    CooldownSnapshot memory cooldownSnapshot = _getERC4626StakeTokenStorage()._stakerCooldown[
      owner
    ];

    if (
      block.timestamp >= cooldownSnapshot.endOfCooldown &&
      block.timestamp - cooldownSnapshot.endOfCooldown <= cooldownSnapshot.withdrawalWindow
    ) {
      return cooldownSnapshot.amount;
    }

    return 0;
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
    return _getERC4626StakeTokenStorage()._totalAssets;
  }

  /// @inheritdoc IERC4626StakeToken
  function getCooldown() public view returns (uint256) {
    return _getERC4626StakeTokenStorage()._cooldown;
  }

  /// @inheritdoc IERC4626StakeToken
  function getUnstakeWindow() public view returns (uint256) {
    return _getERC4626StakeTokenStorage()._unstakeWindow;
  }

  /// @inheritdoc IERC4626StakeToken
  function getStakerCooldown(address user) public view returns (CooldownSnapshot memory) {
    return _getERC4626StakeTokenStorage()._stakerCooldown[user];
  }

  /// @inheritdoc IERC4626StakeToken
  function isCooldownOperator(address user, address operator) public view returns (bool) {
    return _getERC4626StakeTokenStorage()._cooldownOperator[user][operator];
  }

  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    super._deposit(caller, receiver, assets, shares);

    _getERC4626StakeTokenStorage()._totalAssets += assets.toUint192();
  }

  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal override {
    super._withdraw(caller, receiver, owner, assets, shares);

    _getERC4626StakeTokenStorage()._totalAssets -= assets.toUint192();
  }

  function _cooldown(address from) internal virtual {
    uint256 amount = balanceOf(from);

    if (amount == 0) {
      revert ZeroBalanceInStaking();
    }

    ERC4626StakeTokenStorage storage $ = _getERC4626StakeTokenStorage();

    CooldownSnapshot memory cooldownSnapshot = CooldownSnapshot({
      amount: amount.toUint192(),
      endOfCooldown: (block.timestamp + $._cooldown).toUint32(),
      withdrawalWindow: $._unstakeWindow
    });

    $._stakerCooldown[from] = cooldownSnapshot;

    emit StakerCooldownUpdated(
      from,
      amount,
      cooldownSnapshot.endOfCooldown,
      cooldownSnapshot.withdrawalWindow
    );
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    uint256 cachedTotalSupply = totalSupply();
    uint256 cachedTotalAssets = totalAssets();

    // `_deposit` & `_transfer`
    // `handleAction` to update rewards for user `to`
    // during `_withdraw` code can't complete this condition
    if (to != address(0)) {
      REWARDS_CONTROLLER.handleAction(cachedTotalSupply, cachedTotalAssets, to, balanceOf(to));
    }

    // `_withdraw` & `_transfer`
    // `handleAction` to update rewards for user `from`
    // during `_deposit` code can't complete this condition
    if (from != address(0) && from != to) {
      uint256 balanceOfFrom = balanceOf(from);

      REWARDS_CONTROLLER.handleAction(cachedTotalSupply, cachedTotalAssets, from, balanceOfFrom);

      ERC4626StakeTokenStorage storage $ = _getERC4626StakeTokenStorage();
      CooldownSnapshot memory cooldownSnapshot = $._stakerCooldown[from];

      // if cooldown was activated and the user is trying to transfer/redeem tokens
      if (block.timestamp <= cooldownSnapshot.endOfCooldown + cooldownSnapshot.withdrawalWindow) {
        if (to == address(0)) {
          // `from` redeems tokens here
          // reduce the amount available for redemption in the future
          cooldownSnapshot.amount -= value.toUint192();
        } else {
          // `from` transfers tokens here
          // if the balance of the user decreases less than the amount of tokens in cooldown, then his `cooldownSnapshot.amount` should be reduced too
          // we don't pay attention if `balanceAfter` is greater than users `cooldownSnapshot.amount`, because we assume these are "other" tokens;
          // tokens that have been cooldowned are always at the bottom of the balance
          uint192 balanceAfter = (balanceOfFrom - value).toUint192();
          if (balanceAfter < cooldownSnapshot.amount) {
            cooldownSnapshot.amount = balanceAfter;
          }
        }

        // reduce an amount under cooldown if something was spent
        if ($._stakerCooldown[from].amount != cooldownSnapshot.amount) {
          if (cooldownSnapshot.amount == 0) {
            // if user spend all balance or already redeem whole amount
            cooldownSnapshot.endOfCooldown = 0;
            cooldownSnapshot.withdrawalWindow = 0;
          }
          $._stakerCooldown[from] = cooldownSnapshot;
          emit StakerCooldownUpdated(
            from,
            cooldownSnapshot.amount,
            cooldownSnapshot.endOfCooldown,
            cooldownSnapshot.withdrawalWindow
          );
        }
      }
    }

    super._update(from, to, value);
  }

  function _slash(address destination, uint256 amount) internal virtual returns (uint256) {
    if (destination == address(0)) {
      revert ZeroAddress();
    }

    if (amount == 0) {
      revert ZeroAmountSlashing();
    }

    uint256 maxSlashable = _getMaxSlashableAssets();

    if (maxSlashable == 0) {
      revert ZeroFundsAvailable();
    }

    if (amount > maxSlashable) {
      amount = maxSlashable;
    }

    REWARDS_CONTROLLER.handleAction(totalSupply(), totalAssets(), address(0), 0);

    _getERC4626StakeTokenStorage()._totalAssets -= amount.toUint192();

    IERC20(asset()).safeTransfer(destination, amount);

    emit Slashed(destination, amount);

    return amount;
  }

  function _setUnstakeWindow(uint256 newUnstakeWindow) internal {
    uint256 oldUnstakeWindow = _getERC4626StakeTokenStorage()._unstakeWindow;

    _getERC4626StakeTokenStorage()._unstakeWindow = newUnstakeWindow.toUint32();

    emit UnstakeWindowChanged(oldUnstakeWindow, newUnstakeWindow);
  }

  function _setCooldown(uint256 newCooldown) internal {
    uint256 oldCooldown = _getERC4626StakeTokenStorage()._cooldown;

    _getERC4626StakeTokenStorage()._cooldown = newCooldown.toUint32();

    emit CooldownChanged(oldCooldown, newCooldown);
  }

  function _setCooldownOperator(address user, address operator, bool flag) internal {
    _getERC4626StakeTokenStorage()._cooldownOperator[user][operator] = flag;

    emit CooldownOperatorSet(user, operator, flag);
  }

  function _useCooldownNonce(address owner) internal returns (uint256) {
    unchecked {
      return _getERC4626StakeTokenStorage()._cooldownNonces[owner]++;
    }
  }

  function _getMaxSlashableAssets() internal view virtual returns (uint256) {
    uint256 currentAssets = totalAssets();
    return currentAssets <= MIN_ASSETS_REMAINING ? 0 : currentAssets - MIN_ASSETS_REMAINING;
  }
}
