// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IUmbrellaStkManager} from '../umbrella/interfaces/IUmbrellaStkManager.sol';
import {IUmbrellaConfiguration} from '../umbrella/interfaces/IUmbrellaConfiguration.sol';

import {IRewardsStructs} from '../rewards/interfaces/IRewardsStructs.sol';

interface IUmbrellaEngineStructs {
  // umbrella
  /////////////////////////////////////////////////////////////////////////////////////////

  struct ChangeUnstake {
    address umbrella;
    IUmbrellaStkManager.UnstakeWindowConfig[] unstakeWindowConfigs;
  }

  struct ChangeCooldown {
    address umbrella;
    IUmbrellaStkManager.CooldownConfig[] cooldownConfigs;
  }

  struct CreateStkToken {
    address umbrella;
    IUmbrellaStkManager.StakeTokenSetup[] stakeSetups;
  }

  struct RemoveConfig {
    address umbrella;
    IUmbrellaConfiguration.SlashingConfigRemoval[] configRemovals;
  }

  struct UpdateConfig {
    address umbrella;
    IUmbrellaConfiguration.SlashingConfigUpdate[] configUpdates;
  }

  struct SetDeficitOffset {
    address umbrella;
    address reserve;
    uint256 amount;
  }

  struct CoverDeficit {
    address umbrella;
    address reserve;
    uint256 amount;
    bool approve;
  }

  // rewardsController
  /////////////////////////////////////////////////////////////////////////////////////////

  struct StakeAndRewardConfig {
    address rewardsController;
    address stakeToken;
    uint256 targetLiquidity;
    IRewardsStructs.RewardSetupConfig[] rewardConfigs;
  }

  struct RewardConfig {
    address rewardsController;
    address stakeToken;
    IRewardsStructs.RewardSetupConfig[] rewardConfigs;
  }
}
