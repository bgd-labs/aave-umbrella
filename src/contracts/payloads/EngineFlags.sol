// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library EngineFlags {
  /**
   * @dev Magic value to be used as flag to keep unchanged any current configuration.
   * Strongly assumes that the value `type(uint256).max - 42` will never be used, which seems reasonable
   *
   * For now could be used for:
   *   - `unstakeWindow (inside `UnstakeConfig`)
   *   - `cooldown` (inside `UnstakeConfig`)
   *   - `targetLiquidity` (inside `ConfigureStakeAndRewardsConfig`)
   *   - `rewardConfigs[i].maxEmissionPerSecond` (inside `ConfigureStakeAndRewardsConfig` and `ConfigureRewardsConfig`)
   *   - `rewardConfigs[i].distributionEnd` (inside `ConfigureStakeAndRewardsConfig` and `ConfigureRewardsConfig`)
   */
  uint256 internal constant KEEP_CURRENT = type(uint256).max - 42;
}
