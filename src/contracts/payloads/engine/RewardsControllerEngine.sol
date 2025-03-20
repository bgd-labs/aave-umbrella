// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

import {IUmbrellaEngineStructs as IStructs} from '../IUmbrellaEngineStructs.sol';

import {IRewardsController} from '../../rewards/interfaces/IRewardsController.sol';
import {IRewardsDistributor} from '../../rewards/interfaces/IRewardsDistributor.sol';

library RewardsControllerEngine {
  using Address for address;

  function executeConfigureStakeAndRewards(
    IStructs.StakeAndRewardConfig[] memory configs
  ) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].rewardsController.functionDelegateCall(
        abi.encodeWithSelector(
          IRewardsController.configureAssetWithRewards.selector,
          configs[i].stakeToken,
          configs[i].targetLiquidity,
          configs[i].rewardConfigs
        )
      );
    }
  }

  function executeConfigureRewards(IStructs.RewardConfig[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].rewardsController.functionDelegateCall(
        abi.encodeWithSelector(
          IRewardsController.configureRewards.selector,
          configs[i].stakeToken,
          configs[i].rewardConfigs
        )
      );
    }
  }
}
