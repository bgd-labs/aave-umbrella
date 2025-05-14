// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAutomation} from './IAutomation.sol';

/**
 * @title ISlashingRobot
 * @author BGD Labs
 **/
interface ISlashingRobot is IAutomation {
  /// @notice Attempted to `performUpkeep`, that hadn't slash anything.
  error NoSlashesPerformed();

  /**
   * @notice Emitted when `performUpkeep` is called and the `reserve` is slashed.
   * @param reserve Address of the slashed `reserve`
   * @param amount Amount of the deficit covered
   */
  event ReserveSlashed(address indexed reserve, uint256 amount);

  /**
   * @notice Emitted when owner sets the disable flag for a `reserve`.
   * @param reserve Address of the `reserve` for which `disable` flag is set
   */
  event ReserveDisabled(address indexed reserve, bool disable);

  /**
   * @notice Method to get the maximum slash size.
   *         Max check size is used to limit checking/slashing if `reserve` can be slashed or not
   *         so as to avoid exceeding max gas limit on the automation infra.
   * @return max Max check size
   */
  function MAX_CHECK_SIZE() external view returns (uint256);

  /**
   * @notice Method to get the address of the aave `umbrella` contract.
   * @return address Address of the aave `umbrella` contract
   */
  function UMBRELLA() external view returns (address);

  /**
   * @notice Method to check if automation is disabled for the `reserve` or not.
   * @param reserve Address of the `reserve` to check
   * @return bool Flag if automation is disabled or not for this `reserve`
   **/
  function isDisabled(address reserve) external view returns (bool);

  /**
   * @notice Method called by `owner` to disable/enable automation on the specific reserve.
   * @param reserve Address for which we need to disable/enable automation
   * @param disabled True if automation should be disabled, false otherwise
   */
  function disable(address reserve, bool disabled) external;
}
