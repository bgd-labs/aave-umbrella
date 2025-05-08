// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRewardsController} from '../../rewards/interfaces/IRewardsController.sol';
import {IStakeToken} from '../../stakeToken/interfaces/IStakeToken.sol';

interface IEIP7702UmbrellaHelper {
  struct IOData {
    /// @notice Address of the `StakeToken`
    IStakeToken stakeToken;
    /// @notice Deposit start token or redemption end token
    address edgeToken;
    /// @notice Amount of funds to be deposited or amount of funds to be burned during `redeem`
    uint256 value;
  }

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
   * @notice Returns the `RewardsController` contract address.
   * @return Address wrapped to interface of `RewardsController`
   */
  function REWARDS_CONTROLLER() external returns (IRewardsController);
}
