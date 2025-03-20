// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IRewardsStructs interface
 * @notice An interface containing structures that can be used externally.
 * @author BGD labs
 */
interface IRewardsStructs {
  struct RewardSetupConfig {
    /// @notice Reward address
    address reward;
    /// @notice Address, from which this reward will be transferred (should give approval to this address)
    address rewardPayer;
    /// @notice Maximum possible emission rate of rewards per second
    uint256 maxEmissionPerSecond;
    /// @notice End of the rewards distribution
    uint256 distributionEnd;
  }

  struct AssetDataExternal {
    /// @notice Liquidity value at which there will be maximum emission per second (expected amount of asset to be deposited into `StakeToken`)
    uint256 targetLiquidity;
    /// @notice Timestamp of the last update
    uint256 lastUpdateTimestamp;
  }

  struct RewardDataExternal {
    /// @notice Reward address
    address addr;
    /// @notice Liquidity index of the reward set during the last update
    uint256 index;
    /// @notice Maximum possible emission rate of rewards per second
    uint256 maxEmissionPerSecond;
    /// @notice End of the reward distribution
    uint256 distributionEnd;
  }

  struct EmissionData {
    /// @notice Liquidity value at which there will be maximum emission per second applied
    uint256 targetLiquidity;
    /// @notice Liquidity value after which emission per second will be flat
    uint256 targetLiquidityExcess;
    /// @notice Maximum possible emission rate of rewards per second (can be with or without scaling to 18 decimals, depending on usage in code)
    uint256 maxEmission;
    /// @notice Flat emission value per second (can be with or without scaling, depending on usage in code)
    uint256 flatEmission;
  }

  struct UserDataExternal {
    /// @notice Liquidity index of the user reward set during the last update
    uint256 index;
    /// @notice Amount of accrued rewards that the user earned at the time of his last index update (pending to claim)
    uint256 accrued;
  }

  struct SignatureParams {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }
}
