// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRewardsDistributor} from './IRewardsDistributor.sol';

interface IRewardsController is IRewardsDistributor {
  /**
   * @notice Event is emitted when an asset is initialized.
   * @param asset Address of the new `asset` added
   */
  event AssetInitialized(address indexed asset);

  /**
   * @notice Event is emitted when a `targetLiquidity` of the `asset` is changed.
   * @param asset Address of the `asset`
   * @param newTargetLiquidity New amount of `targetLiquidity` set for the `asset`
   */
  event TargetLiquidityUpdated(address indexed asset, uint256 newTargetLiquidity);

  /**
   * @notice Event is emitted when a `lastUpdatedTimestamp` of the `asset` is updated.
   * @param asset Address of the `asset`
   * @param newTimestamp New value of `lastUpdatedTimestamp` updated for the `asset`
   */
  event LastTimestampUpdated(address indexed asset, uint256 newTimestamp);

  /**
   * @notice Event is emitted when a reward is initialized for concrete `asset`.
   * @param asset Address of the `asset`
   * @param reward Address of the `reward`
   */
  event RewardInitialized(address indexed asset, address indexed reward);

  /**
   * @notice Event is emitted when a reward config is updated.
   * @param asset Address of the `asset`
   * @param reward Address of the `reward`
   * @param maxEmissionPerSecond Amount of maximum possible rewards emission per second
   * @param distributionEnd Timestamp after which distribution ends
   * @param rewardPayer Address from where rewards will be transferred
   */
  event RewardConfigUpdated(
    address indexed asset,
    address indexed reward,
    uint256 maxEmissionPerSecond,
    uint256 distributionEnd,
    address rewardPayer
  );

  /**
   * @notice Event is emitted when a `reward` index is updated.
   * @param asset Address of the `asset`
   * @param reward Address of the `reward`
   * @param newIndex New `reward` index updated for certain `asset`
   */
  event RewardIndexUpdated(address indexed asset, address indexed reward, uint256 newIndex);

  /**
   * @notice Event is emitted when a user interacts with the asset (transfer, mint, burn)  or manually updates the rewards data or claims them
   * @param asset Address of the `asset`
   * @param reward Address of the `reward`, which `user` data is updated
   * @param user Address of the `user` whose `reward` data is updated
   * @param newIndex Reward index set after update
   * @param accruedFromLastUpdate Amount of accrued rewards from last update
   */
  event UserDataUpdated(
    address indexed asset,
    address indexed reward,
    address indexed user,
    uint256 newIndex,
    uint256 accruedFromLastUpdate
  );

  /**
   * @notice Event is emitted when a `user` `reward` is claimed.
   * @param asset Address of the `asset`, whose `reward` was claimed
   * @param reward Address of the `reward`, which is claimed
   * @param user Address of the `user` whose `reward` is claimed
   * @param receiver Address of the funds receiver
   * @param amount Amount of the received funds
   */
  event RewardClaimed(
    address indexed asset,
    address indexed reward,
    address indexed user,
    address receiver,
    uint256 amount
  );

  /**
   * @dev Attempted to update data on the `asset` before it was initialized.
   */
  error AssetNotInitialized(address asset);

  /**
   * @dev Attempted to change the configuration of the `reward` before it was initialized.
   */
  error RewardNotInitialized(address reward);

  /**
   * @dev Attempted to set `distributionEnd` less than `block.timestamp` during `reward` initialization.
   */
  error InvalidDistributionEnd();

  /**
   * @dev Attempted to initialize more rewards than limit.
   */
  error MaxRewardsLengthReached();

  // DEFAULT_ADMIN_ROLE
  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Configures asset: sets `targetLiquidity` and updates `lastUpdatedTimestamp`.
   * If the asset has already been initialized, then updates the rewards indexes and `lastUpdatedTimestamp`,
   * also changes `targetLiquidity`, otherwise initializes asset and rewards.
   * @dev `targetLiquidity` should be greater than 1 whole token.
   * `maxEmissionPerSecond` inside `rewardConfig` should be less than 1000 tokens and greater than 2 wei.
   * It must also be greater than `targetLiquidity * 1000 / 1e18`. Check EmissionMath.sol for more info.
   * if `maxEmissionPerSecond` is zero or `distributionEnd` is less than current `block.timestamp`,
   * then disable distribution for this `reward` if it was previously initialized.
   * It can't initialize already disabled reward.
   * @param asset Address of the `asset` to be configured/initialized
   * @param targetLiquidity Amount of liquidity where will be the maximum emission of rewards per second applied
   * @param rewardConfigs Optional array of reward configs, can be empty
   */
  function configureAssetWithRewards(
    address asset,
    uint256 targetLiquidity,
    RewardSetupConfig[] calldata rewardConfigs
  ) external;

  // REWARDS_ADMIN_ROLE
  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Configures already initialized rewards for certain `asset`: sets `distributionEnd` and `maxEmissionPerSecond`.
   * If any reward hasn't initialized before then it reverts.
   * Before setting new configuration updates all rewards indexes for `asset`.
   * @dev `maxEmissionPerSecond` inside `rewardConfig` should be less than 1000 tokens and greater than 2 wei.
   * It must also be greater than `targetLiquidity * 1000 / 1e18`. Check EmissionMath.sol for more info.
   * If `maxEmissionPerSecond` is zero or `distributionEnd` is less than the current `block.timestamp`,
   * then distribution for this `reward` will be disabled.
   * @param asset Address of the `asset` whose reward should be configured
   * @param rewardConfigs Array of structs with params to set
   */
  function configureRewards(address asset, RewardSetupConfig[] calldata rewardConfigs) external;

  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Special hook, which is called every time `StakeToken` makes `_update` or `slash`.
   * Makes an update and calculates new `index` and `accrued`. Also updates `lastUpdateTimestamp`.
   * @dev All variables are passed here before the actual update.
   * @param totalSupply Total supply of `StakeToken`
   * @param totalAssets Total assets of `StakeToken`
   * @param user User, whose `index` and rewards accrued will be updated, if address is zero then skips user update
   * @param userBalance Amount of `StakeToken` shares owned by user
   */
  function handleAction(
    uint256 totalSupply,
    uint256 totalAssets,
    address user,
    uint256 userBalance
  ) external;

  /**
   * @notice Updates all `reward` indexes and `lastUpdateTimestamp` for the `asset`.
   * @param asset Address of the `asset` whose rewards will be updated
   */
  function updateAsset(address asset) external;

  /**
   * @notice Returns an array of all initialized assets (all `StakeTokens`, which are initialized here).
   * @dev Return zero data if assets aren't set.
   * @return assets Array of asset addresses
   */
  function getAllAssets() external view returns (address[] memory assets);

  /**
   * @notice Returns an array of all initialized rewards for a certain `asset`.
   * @dev Return zero data if asset or rewards aren't set.
   * @param asset Address of the `asset` whose rewards should be returned
   * @return rewards Array of reward addresses
   */
  function getAllRewards(address asset) external view returns (address[] memory rewards);

  /**
   * @notice Returns all data about the asset and its rewards.
   * @dev Return zero data if asset or rewards aren't set.
   * Function made without some gas optimizations, so it's recommended to avoid calling it often from non-view method or inside batch.
   * If the emission for a specific reward has ended at the time of the call (i.e., block.timestamp >= distributionEnd),
   * the function will return a zero emission, even though there may still be remaining rewards.
   * Note that the actual reward data will be updated the next time someone manually refreshes the data or interacts with the `StakeToken`.
   * @param asset Address of the `asset` whose params should be returned
   * @return assetData `targetLiquidity` and `lastUpdatedTimestamp` inside struct
   * @return rewardsData All data about rewards including addresses and `RewardData`
   */
  function getAssetAndRewardsData(
    address asset
  )
    external
    view
    returns (AssetDataExternal memory assetData, RewardDataExternal[] memory rewardsData);

  /**
   * @notice Returns data about the asset.
   * @dev Return zero data if asset isn't set.
   * @param asset Address of the `asset` whose params should be returned
   * @return assetData `targetLiquidity` and `lastUpdatedTimestamp` inside struct
   */
  function getAssetData(address asset) external view returns (AssetDataExternal memory assetData);

  /**
   * @notice Returns data about the reward.
   * @dev Return zero data if asset or rewards aren't set.
   * If the emission has ended at the time of the call (i.e., block.timestamp >= distributionEnd), the function will return a zero emission,
   * even though there may still be remaining rewards.
   * Note that the actual reward data will be updated the next time someone manually refreshes the data or interacts with the `StakeToken`.
   * @param asset Address of the `asset` whose `reward` params should be returned
   * @param reward Address of the `reward` whose params should be returned
   * @return rewardData `index`, `maxEmissionPerSecond` and `distributionEnd` and address inside struct, address is duplicated from external one
   */
  function getRewardData(
    address asset,
    address reward
  ) external view returns (RewardDataExternal memory rewardData);

  /**
   * @notice Returns data about the reward emission.
   * @dev Return zero data if asset or rewards aren't set.
   * If `maxEmissionPerSecond` is equal to 1 wei, then `flatEmission` will be 0, although in fact it is not 0 and emission is taken into account correctly inside the code.
   * Here this calculation is made specifically to simplify the function behaviour.
   * If the emission has ended at the time of the call (i.e., block.timestamp >= distributionEnd), the function will return a zero max and flat emissions,
   * even though there may still be remaining rewards.
   * Note that the actual reward data will be updated the next time someone manually refreshes the data or interacts with the `StakeToken`.
   * @param asset Address of the `asset` whose `reward` emission params should be returned
   * @param reward Address of the `reward` whose emission params should be returned
   * @return emissionData `targetLiquidity`, `targetLiquidityExcess`, `maxEmission` and `flatEmission` inside struct
   */
  function getEmissionData(
    address asset,
    address reward
  ) external view returns (EmissionData memory emissionData);

  /**
   * @notice Returns `user` `index` and `accrued` for all rewards for certain `asset` at the time of the last user update.
   * If you want to get current `accrued` of all rewards, see `calculateCurrentUserRewards`.
   * @dev Return zero data if asset or rewards aren't set.
   * @param asset Address of the `asset` for which the rewards are accumulated
   * @param user Address of `user` accumulating rewards
   * @return rewards Array of `reward` addresses
   * @return userData `index` and `accrued` inside structs
   */
  function getUserDataByAsset(
    address asset,
    address user
  ) external view returns (address[] memory rewards, UserDataExternal[] memory userData);

  /**
   * @notice Returns `user` `index` and `accrued` for certain `asset` and `reward` at the time of the last user update.
   * If you want to calculate current `accrued` of the `reward`, see `calculateCurrentUserReward`.
   * @dev Return zero data if asset or rewards aren't set.
   * @param asset Address of the `asset` for which the `reward` is accumulated
   * @param reward Address of the accumulating `reward`
   * @param user Address of `user` accumulating rewards
   * @return data `index` and `accrued` inside struct
   */
  function getUserDataByReward(
    address asset,
    address reward,
    address user
  ) external view returns (UserDataExternal memory data);

  /**
   * @notice Returns current `reward` indexes for `asset`.
   * @dev Return zero if asset or rewards aren't set.
   * Function made without some gas optimizations, so it's recommended to avoid calling it often from non-view method or inside batch.
   * @param asset Address of the `asset` whose indexes of rewards should be calculated
   * @return rewards Array of `reward` addresses
   * @return indexes Current indexes
   */
  function calculateRewardIndexes(
    address asset
  ) external view returns (address[] memory rewards, uint256[] memory indexes);

  /**
   * @notice Returns current `index` for certain `asset` and `reward`.
   * @dev Return zero if asset or rewards aren't set.
   * @param asset Address of the `asset` whose `index` of `reward` should be calculated
   * @param reward Address of the accumulating `reward`
   * @return index Current `index`
   */
  function calculateRewardIndex(
    address asset,
    address reward
  ) external view returns (uint256 index);

  /**
   * @notice Returns `emissionPerSecondScaled` for certain `asset` and `reward`. Returned value scaled to 18 decimals.
   * @dev Return zero if asset or rewards aren't set.
   * @param asset Address of the `asset` which current emission of `reward` should be returned
   * @param reward Address of the `reward` which `emissionPerSecond` should be returned
   * @return emissionPerSecondScaled Current amount of rewards distributed every second (scaled to 18 decimals)
   */
  function calculateCurrentEmissionScaled(
    address asset,
    address reward
  ) external view returns (uint256 emissionPerSecondScaled);

  /**
   * @notice  Returns `emissionPerSecond` for certain `asset` and `reward`.
   * @dev Return zero if asset or rewards aren't set.
   * An integer quantity is returned, although the accuracy of the calculations in reality is higher.
   * @param asset Address of the `asset` which current emission of `reward` should be returned
   * @param reward Address of the `reward` which `emissionPerSecond` should be returned
   * @return emissionPerSecond Current amount of rewards distributed every second
   */
  function calculateCurrentEmission(
    address asset,
    address reward
  ) external view returns (uint256 emissionPerSecond);

  /**
   * @notice Calculates and returns `user` `accrued` amounts for all rewards for certain `asset`.
   * @dev Return zero data if asset or rewards aren't set.
   * Function made without some gas optimizations, so it's recommended to avoid calling it often from non-view method or inside batch.
   * @param asset Address of the `asset` whose rewards are accumulated
   * @param user Address of `user` accumulating rewards
   * @return rewards Array of `reward` addresses
   * @return rewardsAccrued Array of current calculated `accrued` amounts
   */
  function calculateCurrentUserRewards(
    address asset,
    address user
  ) external view returns (address[] memory rewards, uint256[] memory rewardsAccrued);

  /**
   * @notice Calculates and returns `user` `accrued` amount for certain `reward` and `asset`.
   * @dev Return zero if asset or rewards aren't set.
   * @param asset Address of the `asset` whose reward is accumulated
   * @param reward Address of the `reward` that accumulates for the user
   * @param user Address of `user` accumulating rewards
   * @return rewardAccrued Amount of current calculated `accrued` amount
   */
  function calculateCurrentUserReward(
    address asset,
    address reward,
    address user
  ) external view returns (uint256 rewardAccrued);
}
