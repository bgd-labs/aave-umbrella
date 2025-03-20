// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';

import {IRewardsController} from '../../rewards/interfaces/IRewardsController.sol';
import {IStakeToken} from '../../stakeToken/interfaces/IStakeToken.sol';

interface IUmbrellaBatchHelper is IRescuable {
  struct CooldownPermit {
    /// @notice Address of the `StakeToken`, which `cooldown` should be activated via signature
    IStakeToken stakeToken;
    /// @notice Deadline of the signature
    uint256 deadline;
    /// @notice Signature params
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct ClaimPermit {
    /// @notice Address of the `StakeToken`, whose rewards could be claimed or restaked
    IStakeToken stakeToken;
    /// @notice Addresses of the rewards
    address[] rewards;
    /// @notice Deadline of the signature
    uint256 deadline;
    /// @notice Signature params
    uint8 v;
    bytes32 r;
    bytes32 s;
    /// @notice Flag to determine the direction of funds, simply claim or try to make a transfer and restake them
    /// @dev If restake flag is set to true, then signature should be signed using `UmbrellaBatchHelper` contract address as a rewards receiver
    /// @dev Otherwise, the receiver in the signature must match the `msg.sender`
    bool restake;
  }
  /// @dev Doesn't work with `DAI`, as it's incompatible with the `ERC-2612` standard
  struct Permit {
    /// @notice Address of the token to call permit
    address token;
    /// @notice Amount of funds to permit
    uint256 value;
    /// @notice Deadline of the signature
    uint256 deadline;
    /// @notice Signature params
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct IOData {
    /// @notice Address of the `StakeToken`
    IStakeToken stakeToken;
    /// @notice Deposit start token or redemption end token
    address edgeToken;
    /// @notice Amount of funds to be deposited or amount of funds to be burned during `redeem`
    uint256 value;
  }

  /**
   * @notice Event is emitted when the path of `StakeToken` is initialized.
   * @param stakeToken Address of the `StakeToken` which path is initialized
   */
  event AssetPathInitialized(address indexed stakeToken);

  /**
   * @dev Attempted to set zero address.
   */
  error ZeroAddress();

  /**
   * @dev Attempted to use an invalid token for deposit/redeem.
   */
  error InvalidEdgeToken();

  /**
   * @dev Attempted to initialize path for `StakeToken`, which wasn't configured inside `RewardsController`.
   * (Without initialization inside `RewardsController` `StakeToken` isn't working at all.)
   */
  error NotInitializedStake();

  /**
   * @dev Attempted to `deposit/redeem` zero amount.
   */
  error ZeroAmount();

  /**
   * @notice Helps to initialize paths for several `StakeToken`s.
   * @dev Optional, can be skipped, useful to avoid overpaying gas for early adopters of new `StakeToken`s.
   * @param stakeTokens Array of `StakeToken`s
   */
  function initializePath(IStakeToken[] calldata stakeTokens) external;

  /**
   * @notice Trigger `cooldown` on specified `StakeToken` via signature.
   * @param cooldownPermit_ Struct with necessary data and signature.
   */
  function cooldownPermit(CooldownPermit calldata cooldownPermit_) external;

  /**
   * @notice Claims rewards using a signature.
   * @dev Transfers rewards to `_msgSender`, in the token accrued or in `StakeToken`s, depending on the `restake` option.
   *
   * The user must specify the `StakeToken` and the list of rewards to claim, along with a valid signature for the helper contract.
   * - If `restake` is `true`, the rewards receiver (used in the signature) should be this contract.
   * - Otherwise, signature will use `_msgSender` as rewards recipient.
   *
   * Regardless of the `restake` option, `msg.sender` always receives rewards from the `RewardsController` or freshly minted `StakeToken`s (if possible).
   *
   * @param claimPermit_ Struct containing the required data and signature.
   */
  function claimRewardsPermit(ClaimPermit calldata claimPermit_) external;

  /**
   * @notice Adjusts the user's token allowance for this helper contract via permit signature.
   * @dev This function should be used in conjunction with the `deposit/redeem` functions.
   * It allows this contract to call `transferFrom` or `redeem` on behalf of `_msgSender` during token `deposit/redeem`.
   * @param permit_ Struct containing the required data and signature.
   */
  function permit(Permit calldata permit_) external;

  /**
   * @notice Handles deposits
   * @dev The necessary `allowance` must be allocated before the call, for example by using `permit`.
   *
   * `edgeToken` should indicate the token used to start the deposit process from in order to receive a `StakeToken`.
   * The user can start with a `Token`, `aToken` or `StataToken`.
   *
   * If the specified token's address cannot be used for direct deposit to the `StakeToken`
   * (via `StataToken`, if required), the transaction will fail.
   *
   * @param io Struct containing the required data.
   */
  function deposit(IOData calldata io) external;

  /**
   * @notice Handles redemptions.
   * @dev The necessary `allowance` must be allocated before the call, for example by using `permit`.
   * When withdrawing funds, the user must specify the desired output token using the `edgeToken`.
   *
   * If the specified token's address cannot be used for direct redemption from the `StakeToken` (via `StataToken`, if required),
   * the transaction will fail.
   *
   * @param io Struct containing the required data.
   */
  function redeem(IOData calldata io) external;

  /**
   * @notice Pauses the contract, can be called by `owner`.
   * Emits a {Paused} event.
   */
  function pause() external;

  /**
   * @notice Unpauses the contract, can be called by `owner`.
   * Emits a {Unpaused} event.
   */
  function unpause() external;

  /**
   * @notice Returns the `RewardsController` contract address.
   * @return Address wrapped to interface of `RewardsController`
   */
  function REWARDS_CONTROLLER() external returns (IRewardsController);
}
