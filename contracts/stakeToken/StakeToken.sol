// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {PausableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol';
import {ERC20Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol';
import {ERC20PermitUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import {ERC4626Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC4626} from 'openzeppelin-contracts/contracts/interfaces/IERC4626.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {ECDSA} from 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

import {IRescuable, IRescuableBase} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {Rescuable, RescuableBase} from 'solidity-utils/contracts/utils/Rescuable.sol';

import {IERC4626StakeToken} from './interfaces/IERC4626StakeToken.sol';

import {IRewardsController} from '../rewards/interfaces/IRewardsController.sol';

import {ERC4626StakeTokenUpgradeable} from './extension/ERC4626StakeTokenUpgradeable.sol';

/**
 * @title StakeToken
 * @notice StakeToken is an `ERC-4626` contract that aims to supply assets as collateral for emergencies.
 * Stakers will be rewarded through `REWARDS_CONTROLLER` for providing underlying assets. The `slash` function
 * can be called by the owner. It reduces the amount of assets in this vault and transfers them to the recipient.
 * Thus, in exchange for rewards, users' underlying assets may decrease over time.
 * @author BGD labs
 */
contract StakeToken is
  PausableUpgradeable,
  ERC20PermitUpgradeable,
  ERC4626StakeTokenUpgradeable,
  OwnableUpgradeable,
  Rescuable
{
  bytes32 private constant COOLDOWN_WITH_PERMIT_TYPEHASH =
    keccak256(
      'CooldownWithPermit(address user,address caller,uint256 cooldownNonce,uint256 deadline)'
    );

  constructor(
    IRewardsController rewardsController
  ) ERC4626StakeTokenUpgradeable(rewardsController) {
    _disableInitializers();
  }

  function initialize(
    IERC20 stakedToken,
    string calldata name,
    string calldata symbol,
    address owner,
    uint256 cooldown_,
    uint256 unstakeWindow_
  ) external virtual initializer {
    __ERC20_init(name, symbol);
    __ERC20Permit_init(name);

    __Pausable_init();

    __Ownable_init(owner);

    __ERC4626StakeTokenUpgradeable_init(stakedToken, cooldown_, unstakeWindow_);
  }

  /// @inheritdoc IERC4626StakeToken
  function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    SignatureParams calldata sig
  ) external returns (uint256) {
    try
      IERC20Permit(asset()).permit(
        _msgSender(),
        address(this),
        assets,
        deadline,
        sig.v,
        sig.r,
        sig.s
      )
    {} catch {}

    return deposit(assets, receiver);
  }

  /// @inheritdoc IERC4626StakeToken
  function cooldownWithPermit(
    address user,
    uint256 deadline,
    SignatureParams calldata sig
  ) external {
    if (block.timestamp > deadline) {
      revert ERC2612ExpiredSignature(deadline);
    }

    bytes32 structHash = keccak256(
      abi.encode(
        COOLDOWN_WITH_PERMIT_TYPEHASH,
        user,
        _msgSender(),
        _useCooldownNonce(user),
        deadline
      )
    );

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSA.recover(hash, sig.v, sig.r, sig.s);
    if (signer != user) {
      revert ERC2612InvalidSigner(signer, user);
    }

    _cooldown(user);
  }

  /// @inheritdoc IERC4626StakeToken
  function pause() external onlyOwner {
    _pause();
  }

  /// @inheritdoc IERC4626StakeToken
  function unpause() external onlyOwner {
    _unpause();
  }

  /// @inheritdoc IERC4626StakeToken
  function slash(
    address destination,
    uint256 amount
  ) external override onlyOwner returns (uint256) {
    return _slash(destination, amount);
  }

  /// @inheritdoc IERC4626StakeToken
  function setUnstakeWindow(uint256 newUnstakeWindow) external override onlyOwner {
    _setUnstakeWindow(newUnstakeWindow);
  }

  /// @inheritdoc IERC4626StakeToken
  function setCooldown(uint256 newCooldown) external override onlyOwner {
    _setCooldown(newCooldown);
  }

  /// @inheritdoc IERC4626
  function maxDeposit(
    address receiver
  ) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
    if (paused()) {
      return 0;
    }

    return super.maxDeposit(receiver);
  }

  /// @inheritdoc IERC4626
  function maxMint(
    address receiver
  ) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
    if (paused()) {
      return 0;
    }

    return super.maxMint(receiver);
  }

  /// @inheritdoc IERC4626
  function maxWithdraw(address owner) public view override returns (uint256) {
    if (paused()) {
      return 0;
    }

    return super.maxWithdraw(owner);
  }

  /// @inheritdoc IERC4626
  function maxRedeem(address owner) public view override returns (uint256) {
    if (paused()) {
      return 0;
    }

    return super.maxRedeem(owner);
  }

  function whoCanRescue() public view override returns (address) {
    return owner();
  }

  function decimals()
    public
    view
    override(ERC20Upgradeable, ERC4626Upgradeable, IERC20Metadata)
    returns (uint8)
  {
    return super.decimals();
  }

  /// @dev Tokens can be rescued even if the contract is on pause
  function maxRescue(
    address erc20Token
  ) public view override(IRescuableBase, RescuableBase) returns (uint256) {
    if (erc20Token == asset()) {
      return IERC20(erc20Token).balanceOf(address(this)) - totalAssets();
    } else {
      return type(uint256).max;
    }
  }

  function _update(
    address from,
    address to,
    uint256 value
  ) internal override(ERC20Upgradeable, ERC4626StakeTokenUpgradeable) whenNotPaused {
    super._update(from, to, value);
  }

  function _slash(
    address destination,
    uint256 amount
  ) internal override whenNotPaused returns (uint256) {
    return super._slash(destination, amount);
  }

  function _cooldown(address from) internal override whenNotPaused {
    super._cooldown(from);
  }

  function _getMaxSlashableAssets() internal view override returns (uint256) {
    if (paused()) {
      return 0;
    }

    return super._getMaxSlashableAssets();
  }
}
