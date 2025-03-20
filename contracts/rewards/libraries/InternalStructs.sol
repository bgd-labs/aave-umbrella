// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/**
 * @title InternalStructs library
 * @notice Structs for internal usage only
 * @author BGD labs
 */
library InternalStructs {
  struct AssetData {
    /// @notice Map of reward token addresses with their configuration and user data
    mapping(address reward => RewardAndUserData) data;
    /// @notice An array of rewards and the corresponding endings of their distribution (duplicated for optimization)
    RewardAddrAndDistrEnd[] rewardsInfo;
    /// @notice The target liquidity value at which the `maxEmissionPerSecond` is applied. (Max value with current `EmissionMath` lib is 1e34/35).
    uint160 targetLiquidity;
    /// @notice Timestamp of the last update
    uint32 lastUpdateTimestamp;
  }

  struct RewardAndUserData {
    /// @notice Reward configuration and index
    RewardData rewardData;
    /// @notice Map of reward token addresses with their user data
    mapping(address user => UserData) userData;
    /// @notice Address from which reward will be transferred
    address rewardPayer;
  }

  // @dev All rewards will be calculated as they are all 18-decimals tokens with the help of this variable
  struct RewardData {
    /// @notice Liquidity index of the reward (with scaling to 18 decimals and SCALING_FACTOR applied)
    uint144 index;
    /// @notice Maximum possible emission rate of rewards per second (scaled to 18 decimals)
    uint72 maxEmissionPerSecondScaled;
    /// @notice End of the reward distribution (DUPLICATED for optimization)
    uint32 distributionEnd;
    /// @notice Difference between 18 and `reward.decimals()`
    uint8 decimalsScaling;
  }

  struct UserData {
    /// @notice Liquidity index of the reward for the user that was set as a result of the last user rewards update
    uint144 index;
    /// @notice Amount of accrued rewards that the user earned at the time of his last index update (pending to claim)
    uint112 accrued;
  }

  struct RewardAddrAndDistrEnd {
    /// @notice Reward address
    address addr;
    /// @notice The end of the reward distribution (DUPLICATED for optimization)
    uint32 distributionEnd;
  }

  struct ExtraParamsForIndex {
    /// @notice Liquidity value at which there will be maximum emission per second
    uint256 targetLiquidity;
    /// @notice Amount of assets remaining inside the `stakeToken`
    uint256 totalAssets;
    /// @notice Amount of `stakeToken` shares minted
    uint256 totalSupply;
  }
}
