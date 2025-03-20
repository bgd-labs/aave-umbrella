// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRewardsStructs} from './IRewardsStructs.sol';

interface IRewardsDistributor is IRewardsStructs {
  /**
   * @notice Event is emitted when a `user` or admin installs/disables `claimer` for claiming user rewards.
   * @param user Address of the `user`
   * @param claimer Address of the `claimer` to install/disable
   * @param caller Address of the `msg.sender` who changes claimer
   * @param flag Flag responsible for setting/disabling `claimer`
   */
  event ClaimerSet(
    address indexed user,
    address indexed claimer,
    address indexed caller,
    bool flag
  );

  /**
   * @dev Attempted to use signature with expired deadline.
   */
  error ExpiredSignature(uint256 deadline);

  /**
   * @dev Mismatched signature.
   */
  error InvalidSigner(address signer, address owner);

  /**
   * @dev Attempted to claim `reward` without authorization.
   */
  error ClaimerNotAuthorized(address claimer, address user);

  /**
   * @dev Attempted to claim rewards for assets while arrays lengths don't match.
   */
  error LengthsDontMatch();

  /**
   * @dev Attempted to set zero address.
   */
  error ZeroAddress();

  // DEFAULT_ADMIN_ROLE
  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Installs/disables `claimer` for claiming `user` rewards.
   * @param user Address of the `user`
   * @param claimer Address of the `claimer` to install/disable
   * @param flag Flag responsible for setting/disabling `claimer`
   */
  function setClaimer(address user, address claimer, bool flag) external;

  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Installs/disables `claimer` for claiming `msg.sender` rewards.
   * @param claimer Address of the `claimer` to install/disable
   * @param flag Flag responsible for setting/disabling `claimer`
   */
  function setClaimer(address claimer, bool flag) external;

  /**
   * @notice Claims all existing `rewards` for a certain `asset` on behalf of `msg.sender`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @dev Always claims all `rewards`.
   * @param asset Address of the `asset` whose `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @return rewards Array containing the addresses of all `reward` tokens claimed
   * @return amounts Array containing the corresponding `amounts` of each `reward` claimed
   */
  function claimAllRewards(
    address asset,
    address receiver
  ) external returns (address[] memory rewards, uint256[] memory amounts);

  /**
   * @notice Claims all existing `rewards` on behalf of `user` for a certain `asset` by `msg.sender`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @dev Always claims all `rewards`.
   * @param asset Address of the `asset` whose `rewards` should be claimed
   * @param user Address of user, which accrued `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @return rewards Array containing the addresses of all `reward` tokens claimed
   * @return amounts Array containing the corresponding `amounts` of each `reward` claimed
   */
  function claimAllRewardsOnBehalf(
    address asset,
    address user,
    address receiver
  ) external returns (address[] memory rewards, uint256[] memory amounts);

  /**
   * @notice Claims all existing `rewards` on behalf of `user` for a certain `asset` using signature.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @dev Always claims all `rewards`.
   * @param asset Address of the `asset` whose `rewards` should be claimed
   * @param user Address of user, which accrued `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @param deadline Signature deadline for claiming
   * @param sig Signature parameters
   * @return rewards Array containing the addresses of all `reward` tokens claimed
   * @return amounts Array containing the corresponding `amounts` of each `reward` claimed
   */
  function claimAllRewardsPermit(
    address asset,
    address user,
    address receiver,
    uint256 deadline,
    SignatureParams calldata sig
  ) external returns (address[] memory rewards, uint256[] memory amounts);

  /**
   * @notice Claims selected `rewards` of `msg.sender` for a certain `asset`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @param asset Address of the `asset` whose `rewards` should be claimed
   * @param rewards Array of `reward` addresses, which should be claimed
   * @param receiver Address of the funds receiver
   * @return amounts Array containing the corresponding `amounts` of each `reward` claimed
   */
  function claimSelectedRewards(
    address asset,
    address[] calldata rewards,
    address receiver
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Claims selected `rewards` on behalf of `user` for a certain `asset` by `msg.sender`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @param asset Address of the `asset` whose `rewards` should be claimed
   * @param rewards Array of `reward` addresses, which should be claimed
   * @param user Address of user, which accrued `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @return amounts Array containing the corresponding `amounts` of each `reward` claimed
   */
  function claimSelectedRewardsOnBehalf(
    address asset,
    address[] calldata rewards,
    address user,
    address receiver
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Claims selected `rewards` on behalf of `user` for a certain `asset` using signature.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @param asset Address of the `asset` whose `rewards` should be claimed
   * @param rewards Array of `reward` addresses, which should be claimed
   * @param user Address of user, which accrued `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @param deadline Signature deadline for claiming
   * @param sig Signature parameters
   * @return amounts Array containing the corresponding `amounts` of each `reward` claimed
   */
  function claimSelectedRewardsPermit(
    address asset,
    address[] calldata rewards,
    address user,
    address receiver,
    uint256 deadline,
    SignatureParams calldata sig
  ) external returns (uint256[] memory amounts);

  /**
   * @notice Claims all existing `rewards` of `msg.sender` across multiple `assets`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @dev Always claims all `rewards`.
   * @param assets Array of addresses representing the `assets`, whose `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @return rewards Two-dimensional array where each inner array contains the addresses of `reward` tokens for a specific `asset`
   * @return amounts Two-dimensional array where each inner array contains the amounts of each `reward` claimed for a specific `asset`
   */
  function claimAllRewards(
    address[] calldata assets,
    address receiver
  ) external returns (address[][] memory rewards, uint256[][] memory amounts);

  /**
   * @notice Claims all existing `rewards` on behalf of `user` across multiple `assets` by `msg.sender`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @dev Always claims all `rewards`.
   * @param assets Array of addresses representing the `assets`, whose `rewards` should be claimed
   * @param user Address of user, which accrued `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @return rewards Two-dimensional array where each inner array contains the addresses of `reward` tokens for a specific `asset`
   * @return amounts Two-dimensional array where each inner array contains the amounts of each `reward` claimed for a specific `asset`
   */
  function claimAllRewardsOnBehalf(
    address[] calldata assets,
    address user,
    address receiver
  ) external returns (address[][] memory rewards, uint256[][] memory amounts);

  /**
   * @notice Claims selected `rewards` of `msg.sender` across multiple `assets`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @param assets Array of addresses representing the `assets`, whose `rewards` should be claimed
   * @param rewards Two-dimensional array where each inner array contains the addresses of `rewards` for a specific `asset`
   * @param receiver Address of the funds receiver
   * @return amounts Two-dimensional array where each inner array contains the amounts of each `reward` claimed for a specific `asset`
   */
  function claimSelectedRewards(
    address[] calldata assets,
    address[][] calldata rewards,
    address receiver
  ) external returns (uint256[][] memory);

  /**
   * @notice Claims selected `rewards` on behalf of `user` across multiple `assets` by `msg.sender`.
   * Makes an update and calculates new `index` and `accrued` `rewards` before claim.
   * @param assets Array of addresses representing the `assets`, whose `rewards` should be claimed
   * @param rewards Two-dimensional array where each inner array contains the addresses of `rewards` for a specific `asset`
   * @param user Address of user, which accrued `rewards` should be claimed
   * @param receiver Address of the funds receiver
   * @return amounts Two-dimensional array where each inner array contains the amounts of each `reward` claimed for a specific `asset`
   */
  function claimSelectedRewardsOnBehalf(
    address[] calldata assets,
    address[][] calldata rewards,
    address user,
    address receiver
  ) external returns (uint256[][] memory);
}
