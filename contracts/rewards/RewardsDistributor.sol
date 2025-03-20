// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Initializable} from 'openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol';
import {NoncesUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/utils/NoncesUpgradeable.sol';
import {EIP712Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol';

import {IERC4626} from 'openzeppelin-contracts/contracts/interfaces/IERC4626.sol';

import {ECDSA} from 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

import {IRewardsDistributor} from './interfaces/IRewardsDistributor.sol';

/**
 * @title RewardsDistributor
 * @notice RewardsDistributor is an abstract contract designed to implement external functions responsible for receiving rewards.
 * The accrual of rewards, their quantity and method of transfer must be implemented in the child contract.
 * Rewards can be claimed by yourself or through `authorizedClaimers`, as well as through using signatures.
 * @author BGD labs
 */
abstract contract RewardsDistributor is
  Initializable,
  NoncesUpgradeable,
  EIP712Upgradeable,
  IRewardsDistributor
{
  /// @custom:storage-location erc7201:umbrella.storage.RewardsDistributor
  struct RewardsDistributorStorage {
    /// @notice Addresses capable of claiming rewards instead of user
    mapping(address user => mapping(address claimer => bool)) authorizedClaimers;
  }

  // keccak256(abi.encode(uint256(keccak256("umbrella.storage.RewardsDistributor")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant RewardsDistributorStorageLocation =
    0x21b0411c7d97c506a34525b56b49eed70b15d28e22527c4589674c84ba9a5200;

  function _getRewardsDistributorStorage()
    private
    pure
    returns (RewardsDistributorStorage storage $)
  {
    assembly {
      $.slot := RewardsDistributorStorageLocation
    }
  }

  bytes32 private constant CLAIM_ALL_TYPEHASH =
    keccak256(
      'ClaimAllRewards(address asset,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
    );

  bytes32 private constant CLAIM_SELECTED_TYPEHASH =
    keccak256(
      'ClaimSelectedRewards(address asset,address[] rewards,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
    );

  modifier onlyAuthorizedClaimer(address user) {
    require(isClaimerAuthorized(user, msg.sender), ClaimerNotAuthorized(msg.sender, user));

    _;
  }

  function __RewardsDistributor_init() internal onlyInitializing {
    __EIP712_init_unchained('RewardsDistributor', '1');
  }

  function __RewardsDistributor_init_unchained() internal onlyInitializing {}

  /// @inheritdoc IRewardsDistributor
  function claimAllRewards(
    address asset,
    address receiver
  ) external returns (address[] memory, uint256[] memory) {
    return _claimAllRewards(asset, msg.sender, receiver);
  }

  /// @inheritdoc IRewardsDistributor
  function claimAllRewardsOnBehalf(
    address asset,
    address user,
    address receiver
  ) external onlyAuthorizedClaimer(user) returns (address[] memory, uint256[] memory) {
    return _claimAllRewards(asset, user, receiver);
  }

  /// @inheritdoc IRewardsDistributor
  function claimAllRewardsPermit(
    address asset,
    address user,
    address receiver,
    uint256 deadline,
    SignatureParams calldata sig
  ) external returns (address[] memory, uint256[] memory) {
    bytes32 structHash = keccak256(
      abi.encode(CLAIM_ALL_TYPEHASH, asset, user, receiver, msg.sender, _useNonce(user), deadline)
    );

    _checkSignature(user, structHash, deadline, sig);

    return _claimAllRewards(asset, user, receiver);
  }

  /// @inheritdoc IRewardsDistributor
  function claimSelectedRewards(
    address asset,
    address[] calldata rewards,
    address receiver
  ) external returns (uint256[] memory) {
    return _claimSelectedRewards(asset, rewards, msg.sender, receiver);
  }

  /// @inheritdoc IRewardsDistributor
  function claimSelectedRewardsOnBehalf(
    address asset,
    address[] calldata rewards,
    address user,
    address receiver
  ) external onlyAuthorizedClaimer(user) returns (uint256[] memory) {
    return _claimSelectedRewards(asset, rewards, user, receiver);
  }

  /// @inheritdoc IRewardsDistributor
  function claimSelectedRewardsPermit(
    address asset,
    address[] calldata rewards,
    address user,
    address receiver,
    uint256 deadline,
    SignatureParams calldata sig
  ) external returns (uint256[] memory) {
    uint256 nonce = _useNonce(user); // cache here, in order to escape stack-too-deep error inside abi.encode
    bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));
    bytes32 structHash = keccak256(
      abi.encode(
        CLAIM_SELECTED_TYPEHASH,
        asset,
        rewardsHash,
        user,
        receiver,
        msg.sender,
        nonce,
        deadline
      )
    );

    _checkSignature(user, structHash, deadline, sig);

    return _claimSelectedRewards(asset, rewards, user, receiver);
  }

  /// @inheritdoc IRewardsDistributor
  function claimAllRewards(
    address[] calldata assets,
    address receiver
  ) external returns (address[][] memory, uint256[][] memory) {
    address[][] memory addresses = new address[][](assets.length);
    uint256[][] memory amounts = new uint256[][](assets.length);

    for (uint256 i; i < assets.length; ++i) {
      (addresses[i], amounts[i]) = _claimAllRewards(assets[i], msg.sender, receiver);
    }

    return (addresses, amounts);
  }

  /// @inheritdoc IRewardsDistributor
  function claimAllRewardsOnBehalf(
    address[] calldata assets,
    address user,
    address receiver
  ) external onlyAuthorizedClaimer(user) returns (address[][] memory, uint256[][] memory) {
    address[][] memory addresses = new address[][](assets.length);
    uint256[][] memory amounts = new uint256[][](assets.length);

    for (uint256 i; i < assets.length; ++i) {
      (addresses[i], amounts[i]) = _claimAllRewards(assets[i], user, receiver);
    }

    return (addresses, amounts);
  }

  /// @inheritdoc IRewardsDistributor
  function claimSelectedRewards(
    address[] calldata assets,
    address[][] calldata rewards,
    address receiver
  ) external returns (uint256[][] memory) {
    require(assets.length == rewards.length, LengthsDontMatch());

    uint256[][] memory amounts = new uint256[][](assets.length);

    for (uint256 i; i < assets.length; ++i) {
      amounts[i] = _claimSelectedRewards(assets[i], rewards[i], msg.sender, receiver);
    }

    return amounts;
  }

  /// @inheritdoc IRewardsDistributor
  function claimSelectedRewardsOnBehalf(
    address[] calldata assets,
    address[][] calldata rewards,
    address user,
    address receiver
  ) external onlyAuthorizedClaimer(user) returns (uint256[][] memory) {
    require(assets.length == rewards.length, LengthsDontMatch());

    uint256[][] memory amounts = new uint256[][](assets.length);

    for (uint256 i; i < assets.length; ++i) {
      amounts[i] = _claimSelectedRewards(assets[i], rewards[i], user, receiver);
    }

    return amounts;
  }

  /// @inheritdoc IRewardsDistributor
  function setClaimer(address claimer, bool flag) external {
    _setClaimer(msg.sender, claimer, flag);
  }

  function isClaimerAuthorized(address user, address claimer) public view returns (bool) {
    return _getRewardsDistributorStorage().authorizedClaimers[user][claimer];
  }

  function _setClaimer(address user, address claimer, bool flag) internal {
    require(claimer != address(0), ZeroAddress());

    _getRewardsDistributorStorage().authorizedClaimers[user][claimer] = flag;

    emit ClaimerSet(user, claimer, msg.sender, flag);
  }

  function _claimAllRewards(
    address asset,
    address user,
    address receiver
  ) internal returns (address[] memory, uint256[] memory) {
    address[] memory rewards = getAllRewards(asset);
    uint256[] memory claimed = _claimSelectedRewards(asset, rewards, user, receiver);

    return (rewards, claimed);
  }

  function _checkSignature(
    address user,
    bytes32 structHash,
    uint256 deadline,
    SignatureParams calldata sig
  ) internal view {
    require(block.timestamp <= deadline, ExpiredSignature(deadline));

    bytes32 hash = _hashTypedDataV4(structHash);
    address signer = ECDSA.recover(hash, sig.v, sig.r, sig.s);

    require(signer == user, InvalidSigner(signer, user));
  }

  function getAllRewards(address asset) public view virtual returns (address[] memory);

  function _claimSelectedRewards(
    address asset,
    address[] memory rewards,
    address user,
    address receiver
  ) internal virtual returns (uint256[] memory);
}
