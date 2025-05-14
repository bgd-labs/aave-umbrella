// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {SlashingRobot, IAutomation} from './SlashingRobot.sol';

/**
 * @title GelatoSlashingRobot
 * @author BGD Labs
 * @notice Contract to perform automated slashing on umbrella
 *         The difference from `SlashingRobot` is that on `checkUpkeep`, we return
 *         the reserve to slash encoded with the function selector
 */
contract GelatoSlashingRobot is SlashingRobot {
  /**
   * @param umbrella Address of the `umbrella` contract
   * @param robotGuardian Address of the robot guardian
   */
  constructor(address umbrella, address robotGuardian) SlashingRobot(umbrella, robotGuardian) {}

  /**
   * @inheritdoc IAutomation
   * @dev run off-chain, checks if reserves should be slashed
   * @dev the returned bytes is specific to gelato and is encoded with the function selector.
   */
  function checkUpkeep(bytes memory) public view virtual override returns (bool, bytes memory) {
    (bool upkeepNeeded, bytes memory encodedReservesToSlash) = super.checkUpkeep('');

    return (upkeepNeeded, abi.encodeCall(this.performUpkeep, encodedReservesToSlash));
  }
}
