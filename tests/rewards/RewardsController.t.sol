// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';

import {EmissionMath} from '../../src/contracts/rewards/libraries/EmissionMath.sol';
import {IRewardsController} from '../../src/contracts/rewards/interfaces/IRewardsController.sol';
import {RewardsControllerBaseTest, StakeToken, IRewardsDistributor, IRewardsStructs} from './utils/RewardsControllerBase.t.sol';

contract RewardsControllerTest is RewardsControllerBaseTest {
  uint256 internal constant MAX_EMISSION_VALUE_PER_SECOND = 100 * 1e18;

  function test_configureAssetWithRewards18With18(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecond
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    validMaxEmissionPerSecond = bound(
      validMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

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

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.targetLiquidity, targetLiquidity);
    assertEq(emissionData.targetLiquidityExcess, (targetLiquidity * 12_000) / 10_000);
    assertEq(emissionData.maxEmission, validMaxEmissionPerSecond);
    assertEq(emissionData.flatEmission, (validMaxEmissionPerSecond * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.addr, address(reward18Decimals));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, validMaxEmissionPerSecond);
    assertEq(rewardData.distributionEnd, (block.timestamp + 2 * 365 days));

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );

    assertEq(assetData.targetLiquidity, targetLiquidity);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);
  }

  function test_configureAssetWithRewards6With18(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecondScaled
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    validMaxEmissionPerSecondScaled = bound(
      validMaxEmissionPerSecondScaled,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

    // 18 - 6 = 12
    uint256 validMaxEmissionPerSecondNonScaled = validMaxEmissionPerSecondScaled / (10 ** 12);

    if (validMaxEmissionPerSecondNonScaled * 10 ** 12 < targetLiquidity / 1e15 + 2) {
      validMaxEmissionPerSecondNonScaled += 2;
    }

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward6Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: validMaxEmissionPerSecondNonScaled,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertEq(emissionData.targetLiquidity, targetLiquidity);
    assertEq(emissionData.targetLiquidityExcess, (targetLiquidity * 12_000) / 10_000);
    assertEq(emissionData.maxEmission, validMaxEmissionPerSecondNonScaled);
    assertEq(emissionData.flatEmission, (validMaxEmissionPerSecondNonScaled * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertEq(rewardData.addr, address(reward6Decimals));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, validMaxEmissionPerSecondNonScaled);
    assertEq(rewardData.distributionEnd, (block.timestamp + 2 * 365 days));

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );

    assertEq(assetData.targetLiquidity, targetLiquidity);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);
  }

  function test_configureAssetWithRewards6With6(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecondScaled
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e6, 1e34);

    validMaxEmissionPerSecondScaled = bound(
      validMaxEmissionPerSecondScaled,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

    // 18 - 6 = 12
    uint256 validMaxEmissionPerSecondNonScaled = validMaxEmissionPerSecondScaled / (10 ** 12);

    if (validMaxEmissionPerSecondNonScaled * 10 ** 12 < targetLiquidity / 1e15 + 2) {
      validMaxEmissionPerSecondNonScaled += 2;
    }

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward6Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: validMaxEmissionPerSecondNonScaled,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith6Decimals),
      targetLiquidity,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith6Decimals),
      address(reward6Decimals)
    );

    assertEq(emissionData.targetLiquidity, targetLiquidity);
    assertEq(emissionData.targetLiquidityExcess, (targetLiquidity * 12_000) / 10_000);
    assertEq(emissionData.maxEmission, validMaxEmissionPerSecondNonScaled);
    assertEq(emissionData.flatEmission, (validMaxEmissionPerSecondNonScaled * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith6Decimals),
      address(reward6Decimals)
    );

    assertEq(rewardData.addr, address(reward6Decimals));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, validMaxEmissionPerSecondNonScaled);
    assertEq(rewardData.distributionEnd, (block.timestamp + 2 * 365 days));

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith6Decimals)
    );

    assertEq(assetData.targetLiquidity, targetLiquidity);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);
  }

  function test_configureAssetWithRewards18With6(
    uint256 targetLiquidity,
    uint256 validMaxEmissionPerSecond
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e6, 1e34);

    validMaxEmissionPerSecond = bound(
      validMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2, // 2 wei minimum
      1_000 * 1e18
    );

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: validMaxEmissionPerSecond,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith6Decimals),
      targetLiquidity,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith6Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.targetLiquidity, targetLiquidity);
    assertEq(emissionData.targetLiquidityExcess, (targetLiquidity * 12_000) / 10_000);
    assertEq(emissionData.maxEmission, validMaxEmissionPerSecond);
    assertEq(emissionData.flatEmission, (validMaxEmissionPerSecond * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith6Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.addr, address(reward18Decimals));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, validMaxEmissionPerSecond);
    assertEq(rewardData.distributionEnd, (block.timestamp + 2 * 365 days));

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith6Decimals)
    );

    assertEq(assetData.targetLiquidity, targetLiquidity);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);
  }

  function test_configureAssetWithRewardsByNotAdmin() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        address(someone),
        bytes32(0x00)
      )
    );

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );
  }

  function test_configureZeroAddresses() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(0),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    vm.expectRevert(abi.encodeWithSelector(IRewardsDistributor.ZeroAddress.selector));
    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );

    rewards[0].reward = address(reward18Decimals);
    rewards[0].rewardPayer = address(0);

    vm.expectRevert(abi.encodeWithSelector(IRewardsDistributor.ZeroAddress.selector));
    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );
  }

  function test_configureAssetWithRewardsWithInvalidTarget(uint256 targetLiquidity) public {
    targetLiquidity = bound(targetLiquidity, 0, 1e18 - 1);

    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: block.timestamp + 1
    });

    vm.expectRevert(abi.encodeWithSelector(EmissionMath.InvalidTargetLiquidity.selector));

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    targetLiquidity = bound(targetLiquidity, 1e36 + 1, type(uint256).max);

    vm.expectRevert(abi.encodeWithSelector(EmissionMath.InvalidTargetLiquidity.selector));

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );
  }

  function test_configureAssetWithRewardsWithInvalidEmissionTooLow(
    uint256 targetLiquidity,
    uint256 invalidMaxEmissionPerSecond
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    uint256 precisionBound = targetLiquidity / 1e15;
    uint256 minBound = precisionBound > 2 ? precisionBound : 2;

    invalidMaxEmissionPerSecond = bound(invalidMaxEmissionPerSecond, 0, minBound - 1);

    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: invalidMaxEmissionPerSecond,
      distributionEnd: block.timestamp + 1
    });

    vm.expectRevert(abi.encodeWithSelector(EmissionMath.InvalidMaxEmissionPerSecond.selector));

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );
  }

  function test_configureAssetWithRewardsWithInvalidEmissionTooHigh(
    uint256 targetLiquidity,
    uint256 maxEmissionPerSecond
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);
    maxEmissionPerSecond = bound(maxEmissionPerSecond, 1000 * 1e18 + 1, type(uint256).max);

    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: maxEmissionPerSecond,
      distributionEnd: block.timestamp + 1
    });

    vm.expectRevert(abi.encodeWithSelector(EmissionMath.InvalidMaxEmissionPerSecond.selector));

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );
  }

  function test_configureAssetWithRewardsWithInvalidDistributionEnd() public {
    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: block.timestamp
    });

    vm.expectRevert(abi.encodeWithSelector(IRewardsController.InvalidDistributionEnd.selector));

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );

    // check that timestamp from past can't be initialized too
    rewards[0].distributionEnd -= 1;

    vm.expectRevert(abi.encodeWithSelector(IRewardsController.InvalidDistributionEnd.selector));

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );
  }

  function test_configureRewardsNotByRewardAdmin() public {
    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();
    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        address(someone),
        REWARDS_ADMIN_ROLE
      )
    );

    rewardsController.configureRewards(address(stakeWith18Decimals), rewards);
  }

  function test_configureRewardsWithNotInitializedReward() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(rewardsAdmin);

    vm.expectRevert(
      abi.encodeWithSelector(
        IRewardsController.RewardNotInitialized.selector,
        address(reward18Decimals)
      )
    );

    rewardsController.configureRewards(address(stakeWith18Decimals), rewards);
  }

  function test_configureRewardsWithInvalidEmissionTooLow(
    uint256 targetLiquidity,
    uint256 invalidMaxEmissionPerSecond
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);

    uint256 precisionBound = targetLiquidity / 1e15;
    uint256 minBound = precisionBound > 2 ? precisionBound : 2;

    invalidMaxEmissionPerSecond = bound(invalidMaxEmissionPerSecond, 1, minBound - 1); // from 1, cause 0 will just disable reward

    uint256 rightMaxEmissionPerSecond = 1e18;
    rightMaxEmissionPerSecond = bound(
      rightMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2,
      100e18
    );

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: rightMaxEmissionPerSecond,
      distributionEnd: block.timestamp + 1
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    vm.stopPrank();
    vm.startPrank(rewardsAdmin);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: invalidMaxEmissionPerSecond,
      distributionEnd: block.timestamp + 1
    });

    vm.expectRevert(abi.encodeWithSelector(EmissionMath.InvalidMaxEmissionPerSecond.selector));
    rewardsController.configureRewards(address(stakeWith18Decimals), rewards);
  }

  function test_configureRewardsWithInvalidEmissionTooHigh(
    uint256 targetLiquidity,
    uint256 invalidMaxEmissionPerSecond
  ) public {
    targetLiquidity = bound(targetLiquidity, 1e18, 1e34);
    invalidMaxEmissionPerSecond = bound(
      invalidMaxEmissionPerSecond,
      1000 * 1e18 + 1,
      type(uint256).max
    );

    uint256 rightMaxEmissionPerSecond = 1e18;
    rightMaxEmissionPerSecond = bound(
      rightMaxEmissionPerSecond,
      targetLiquidity / 1e15 + 2,
      100e18
    );

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: rightMaxEmissionPerSecond,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      targetLiquidity,
      rewards
    );

    vm.stopPrank();
    vm.startPrank(rewardsAdmin);

    rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: invalidMaxEmissionPerSecond,
      distributionEnd: block.timestamp + 1
    });

    vm.expectRevert(abi.encodeWithSelector(EmissionMath.InvalidMaxEmissionPerSecond.selector));
    rewardsController.configureRewards(address(stakeWith18Decimals), rewards);
  }

  function test_configureAssetDisableRewardWithTime() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 1e18);
    assertEq(emissionData.flatEmission, (1e18 * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 1e18);
    assertEq(rewardData.distributionEnd, block.timestamp + 2 * 365 days);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp - 1)
    });

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);

    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, block.timestamp);
  }

  function test_configureAssetDisableRewardWithEmission() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 1e18);
    assertEq(emissionData.flatEmission, (1e18 * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 1e18);
    assertEq(rewardData.distributionEnd, block.timestamp + 2 * 365 days);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 0,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);

    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, block.timestamp);
  }

  function test_configureRewardsDisableRewardWithTime() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 1e18);
    assertEq(emissionData.flatEmission, (1e18 * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 1e18);
    assertEq(rewardData.distributionEnd, block.timestamp + 2 * 365 days);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp - 1)
    });

    vm.startPrank(rewardsAdmin);

    rewardsController.configureRewards(address(stakeWith18Decimals), rewards);

    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);

    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, block.timestamp);
  }

  function test_configureRewardsDisableRewardWithEmission() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);
    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 1e18);
    assertEq(emissionData.flatEmission, (1e18 * 8_000) / 10_000);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 1e18);
    assertEq(rewardData.distributionEnd, block.timestamp + 2 * 365 days);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 0,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(rewardsAdmin);

    rewardsController.configureRewards(address(stakeWith18Decimals), rewards);

    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);

    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, block.timestamp);
  }

  function test_updateAssetWithoutRewards() public {
    IRewardsStructs.RewardSetupConfig[] memory empty = new IRewardsStructs.RewardSetupConfig[](0);

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      empty
    );

    uint256 startTimestamp = block.timestamp;

    vm.stopPrank();

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );

    assertEq(assetData.lastUpdateTimestamp, startTimestamp);

    skip(1 days);

    // data shouldn't be updated
    rewardsController.updateAsset(address(stakeWith18Decimals));

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));

    assertEq(assetData.lastUpdateTimestamp, startTimestamp);

    _dealStakeToken(stakeWith18Decimals, user, 1_000);

    skip(1 days);

    // data should be updated
    rewardsController.updateAsset(address(stakeWith18Decimals));

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));

    assertNotEq(assetData.lastUpdateTimestamp, startTimestamp);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);
  }

  function test_handleActionWithRewards() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](2);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewards[1] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward6Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e6,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );

    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    skip(1 days);

    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));

    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.UserDataExternal memory userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(userData.accrued, 0);
    assertEq(userData.index, 0);

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward6Decimals),
      user
    );

    assertEq(userData.accrued, 0);
    assertEq(userData.index, 0);

    skip(1 days);

    vm.startPrank(user);
    stakeWith18Decimals.transfer(someone, 1);
    vm.stopPrank();

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));

    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertGt(userData.accrued, 0);
    assertGt(userData.index, 0);

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward6Decimals),
      user
    );

    assertGt(userData.accrued, 0);
    assertGt(userData.index, 0);
  }

  function test_handleActionUninitializedAsset() public {
    _dealUnderlying(stakeWith6Decimals.asset(), user, 1e18);

    vm.startPrank(user);

    IERC20(stakeWith6Decimals.asset()).approve(address(stakeWith6Decimals), 1e18);

    vm.expectRevert(
      abi.encodeWithSelector(
        IRewardsController.AssetNotInitialized.selector,
        address(stakeWith6Decimals)
      )
    );
    stakeWith6Decimals.deposit(1e18, user);
  }

  function test_updateAssetAndRewardDataOnDeposit() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardDataOld = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertEq(rewardDataOld.index, 0);

    skip(1 days);

    // update of index is not instant, update will be performed on the next action
    // cause now we are calculating previous period of time
    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardDataNew = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertEq(rewardDataNew.index, rewardDataOld.index);
    rewardDataOld = rewardDataNew;

    skip(1 days);

    vm.startPrank(user);
    stakeWith18Decimals.transfer(someone, 1);
    vm.stopPrank();

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    rewardDataNew = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertGt(rewardDataNew.index, rewardDataOld.index);

    IRewardsStructs.UserDataExternal memory userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertGt(userData.index, 0);
    assertGt(userData.accrued, 0);
    assertEq(userData.index, rewardDataNew.index);
  }

  function test_updateAssetAndRewardDataOnWithdraw() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardDataOld = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertEq(rewardDataOld.index, 0);

    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    vm.startPrank(user);
    stakeWith18Decimals.cooldown();

    skip(15 days);

    stakeWith18Decimals.withdraw(1_000 * 1e18, user, user);

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardDataNew = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertGt(rewardDataNew.index, rewardDataOld.index);
    rewardDataOld = rewardDataNew;

    IRewardsStructs.UserDataExternal memory userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );
    assertGt(userData.index, 0);
    assertGt(userData.accrued, 0);
    assertEq(userData.index, rewardDataNew.index);

    uint256 oldIndex = userData.index;
    uint256 oldAccrued = userData.accrued;

    skip(1 days);

    stakeWith18Decimals.redeem(1_000 * 1e18, user, user);

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    rewardDataNew = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertGt(rewardDataNew.index, rewardDataOld.index);

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertGt(userData.index, oldIndex);
    assertGt(userData.accrued, oldAccrued);
    assertEq(userData.index, rewardDataNew.index);
  }

  function test_updateAssetAndRewardDataOnSlash() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardDataOld = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertEq(rewardDataOld.index, 0);

    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    skip(1 days);

    vm.startPrank(umbrellaController);
    stakeWith18Decimals.slash(someone, 1_000 * 1e18);

    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardDataNew = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertGt(rewardDataNew.index, rewardDataOld.index);
    rewardDataOld = rewardDataNew;
  }

  function test_updateAssetAndRewardDataOnTransfer() public {
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e18,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      1_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();

    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    skip(1 days);

    vm.startPrank(user);

    stakeWith18Decimals.transfer(someone, 1_000 * 1e18);

    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith18Decimals)
    );
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertGt(rewardData.index, 0);

    IRewardsStructs.UserDataExternal memory userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(userData.index, rewardData.index);
    assertGt(userData.accrued, 0);

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      someone
    );

    assertEq(userData.index, rewardData.index);
  }
}
