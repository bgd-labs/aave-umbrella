// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';

import {EmissionMath} from '../../src/contracts/rewards/libraries/EmissionMath.sol';
import {IRewardsController} from '../../src/contracts/rewards/interfaces/IRewardsController.sol';
import {RewardsControllerBaseTest, StakeToken, IRewardsDistributor, IRewardsStructs} from './utils/RewardsControllerBase.t.sol';

contract RewardsControllerTest is RewardsControllerBaseTest {
  function test_CurveSector_1(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecond,
    uint256 amountOfAssets
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    validMaxEmissionPerSecond = bound(
      validMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

    amountOfAssets = bound(amountOfAssets, 1, targetLiquidity);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: validMaxEmissionPerSecond,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    _dealStakeToken(stakeWith18Decimals, user, amountOfAssets);

    uint256 currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertGe(currentEmission, 0);
    assertGe(validMaxEmissionPerSecond, currentEmission);

    if (amountOfAssets > targetLiquidity) {
      assertGt(currentEmission, (3 * validMaxEmissionPerSecond) / 4);
    }
  }

  function test_CurveSector_2(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecond,
    uint256 amountOfAssets
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    validMaxEmissionPerSecond = bound(
      validMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

    amountOfAssets = bound(amountOfAssets, targetLiquidity, (targetLiquidity * 12_000) / 10_000);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: validMaxEmissionPerSecond,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    _dealStakeToken(stakeWith18Decimals, user, amountOfAssets);

    uint256 currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertGe(currentEmission, (8_000 * validMaxEmissionPerSecond) / 10_000);
    assertGe(validMaxEmissionPerSecond, currentEmission);
  }

  function test_CurveSector_3(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecond,
    uint256 amountOfAssets
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    validMaxEmissionPerSecond = bound(
      validMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

    amountOfAssets = bound(amountOfAssets, (targetLiquidity * 12_000) / 10_000, 1e40);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: validMaxEmissionPerSecond,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    _dealStakeToken(stakeWith18Decimals, user, amountOfAssets);

    uint256 currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(currentEmission, (8_000 * validMaxEmissionPerSecond) / 10_000);
  }
}
