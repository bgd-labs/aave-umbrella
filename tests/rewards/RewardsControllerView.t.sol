// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RewardsControllerBaseTest, StakeToken, IRewardsDistributor, IRewardsStructs} from './utils/RewardsControllerBase.t.sol';

contract RewardsControllerViewTest is RewardsControllerBaseTest {
  function setUp() public override {
    super.setUp();

    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](2);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward18Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewards[1] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward6Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1 wei,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );

    vm.stopPrank();

    _dealUnderlying(address(reward18Decimals), rewardsAdmin, 2 * 365 days * 1e12);
    _dealUnderlying(address(reward6Decimals), rewardsAdmin, 2 * 365 days * 1);

    vm.startPrank(rewardsAdmin);

    reward18Decimals.approve(address(rewardsController), 2 * 365 days * 1e12);
    reward6Decimals.approve(address(rewardsController), 2 * 365 days * 1);
  }

  function test_initialize() public view {
    assert(rewardsController.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin));
    assert(rewardsController.hasRole(REWARDS_ADMIN_ROLE, defaultAdmin));

    (
      ,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,

    ) = rewardsController.eip712Domain();

    assertEq(keccak256(bytes(name)), _hashedName);
    assertEq(keccak256(bytes(version)), _hashedVersion);

    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(rewardsController));
    assertEq(salt, bytes32(0));
  }

  function test_getAllAssets() public {
    address[] memory allAssets = rewardsController.getAllAssets();

    assertEq(allAssets.length, 1);
    assertEq(allAssets[0], address(stakeWith18Decimals));

    // add new asset
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](0);

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith6Decimals),
      10_000_000 * 1e6,
      rewards
    );

    allAssets = rewardsController.getAllAssets();

    assertEq(allAssets.length, 2);
    assertEq(allAssets[0], address(stakeWith18Decimals));
    assertEq(allAssets[1], address(stakeWith6Decimals));
  }

  function test_getAllRewards() public {
    // uninitialized asset
    address[] memory allRewards = rewardsController.getAllRewards(address(stakeWith6Decimals));

    assertEq(allRewards.length, 0);

    // initialized asset
    allRewards = rewardsController.getAllRewards(address(stakeWith18Decimals));

    assertEq(allRewards.length, 2);

    assertEq(allRewards[0], address(reward18Decimals));
    assertEq(allRewards[1], address(reward6Decimals));

    // add new reward
    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(unusedReward),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    vm.startPrank(defaultAdmin);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );

    allRewards = rewardsController.getAllRewards(address(stakeWith18Decimals));

    assertEq(allRewards.length, 3);

    assertEq(allRewards[0], address(reward18Decimals));
    assertEq(allRewards[1], address(reward6Decimals));
    assertEq(allRewards[2], address(unusedReward));
  }

  function test_getAssetAndRewardsData() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    IRewardsStructs.AssetDataExternal memory assetData;
    IRewardsStructs.RewardDataExternal[] memory rewardsData;

    // uninitialized asset
    (assetData, rewardsData) = rewardsController.getAssetAndRewardsData(
      address(stakeWith6Decimals)
    );

    assertEq(assetData.targetLiquidity, 0);
    assertEq(assetData.lastUpdateTimestamp, 0);
    assertEq(rewardsData.length, 0);

    // initialized asset
    (assetData, rewardsData) = rewardsController.getAssetAndRewardsData(
      address(stakeWith18Decimals)
    );

    uint256 distributionEnd = block.timestamp + 2 * 365 days;

    assertEq(assetData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(assetData.lastUpdateTimestamp, 1);
    assertEq(rewardsData.length, 2);

    assertEq(rewardsData[0].addr, address(reward18Decimals));
    assertEq(rewardsData[1].addr, address(reward6Decimals));

    assertEq(rewardsData[0].index, 0);
    assertEq(rewardsData[1].index, 0);

    assertEq(rewardsData[0].maxEmissionPerSecond, 1e12);
    assertEq(rewardsData[1].maxEmissionPerSecond, 1);

    assertEq(rewardsData[0].distributionEnd, distributionEnd);
    assertEq(rewardsData[1].distributionEnd, distributionEnd);

    skip(1);

    rewardsController.updateAsset(address(stakeWith18Decimals));

    // initialized and updated data
    (assetData, rewardsData) = rewardsController.getAssetAndRewardsData(
      address(stakeWith18Decimals)
    );

    assertEq(assetData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);

    assertGt(rewardsData[0].index, 0);
    assertGt(rewardsData[1].index, 0);
  }

  function test_getAssetData() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    // uninitialized asset
    IRewardsStructs.AssetDataExternal memory assetData = rewardsController.getAssetData(
      address(stakeWith6Decimals)
    );

    assertEq(assetData.targetLiquidity, 0);
    assertEq(assetData.lastUpdateTimestamp, 0);

    // initialized asset
    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));

    assertEq(assetData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(assetData.lastUpdateTimestamp, 1);

    skip(1);

    rewardsController.updateAsset(address(stakeWith18Decimals));

    // initialized and updated asset
    assetData = rewardsController.getAssetData(address(stakeWith18Decimals));

    assertEq(assetData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(assetData.lastUpdateTimestamp, block.timestamp);
  }

  function test_getRewardData() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    // uninitialized asset and reward
    IRewardsStructs.RewardDataExternal memory rewardData = rewardsController.getRewardData(
      address(stakeWith6Decimals),
      address(unusedReward)
    );

    assertEq(rewardData.addr, address(unusedReward));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, 0);

    // initialized asset and uninitialized reward
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(unusedReward)
    );

    assertEq(rewardData.addr, address(unusedReward));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, 0);

    // initialized asset and 18 decimals reward
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    uint256 distributionEnd = block.timestamp + 2 * 365 days;

    assertEq(rewardData.addr, address(reward18Decimals));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, 1e12);
    assertEq(rewardData.distributionEnd, distributionEnd);

    // initialized asset and 6 decimals reward
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertEq(rewardData.addr, address(reward6Decimals));
    assertEq(rewardData.index, 0);
    assertEq(rewardData.maxEmissionPerSecond, 1);
    assertEq(rewardData.distributionEnd, distributionEnd);

    skip(distributionEnd + 1);

    // already disabled 18 decimals reward
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, distributionEnd);

    // already disabled 6 decimals reward
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertEq(rewardData.maxEmissionPerSecond, 0);
    assertEq(rewardData.distributionEnd, distributionEnd);

    rewardsController.updateAsset(address(stakeWith18Decimals));

    // index should be updated
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertGt(rewardData.index, 0);

    // index should be updated
    rewardData = rewardsController.getRewardData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertGt(rewardData.index, 0);
  }

  function test_getEmissionData() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    // uninitialized asset and reward
    IRewardsStructs.EmissionData memory emissionData = rewardsController.getEmissionData(
      address(stakeWith6Decimals),
      address(unusedReward)
    );

    assertEq(emissionData.targetLiquidity, 0);
    assertEq(emissionData.targetLiquidityExcess, 0);

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);

    // initialized asset and uninitialized reward
    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(unusedReward)
    );

    assertEq(emissionData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(emissionData.targetLiquidityExcess, 12_000_000 * 1e18);

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);

    // initialized asset and 18 decimals reward
    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );

    assertEq(emissionData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(emissionData.targetLiquidityExcess, 12_000_000 * 1e18);

    assertEq(emissionData.maxEmission, 1e12);
    assertEq(emissionData.flatEmission, 8e11);

    // initialized asset and 6 decimals reward
    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertEq(emissionData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(emissionData.targetLiquidityExcess, 12_000_000 * 1e18);

    assertEq(emissionData.maxEmission, 1);
    // zero, cause we multiply 1 by 80% and get zero value
    assertEq(emissionData.flatEmission, 0);

    skip(2 * 365 days + 1);

    // already disabled emission
    emissionData = rewardsController.getEmissionData(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );

    assertEq(emissionData.targetLiquidity, 10_000_000 * 1e18);
    assertEq(emissionData.targetLiquidityExcess, 12_000_000 * 1e18);

    assertEq(emissionData.maxEmission, 0);
    assertEq(emissionData.flatEmission, 0);
  }

  function test_getUserDataByAsset() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    address[] memory rewards;
    IRewardsStructs.UserDataExternal[] memory userData;

    // uninitialized asset
    (rewards, userData) = rewardsController.getUserDataByAsset(address(stakeWith6Decimals), user);

    assertEq(rewards.length, 0);
    assertEq(userData.length, 0);

    // initialized asset, user data isn't updated
    (rewards, userData) = rewardsController.getUserDataByAsset(address(stakeWith18Decimals), user);

    assertEq(rewards.length, 2);
    assertEq(rewards[0], address(reward18Decimals));
    assertEq(rewards[1], address(reward6Decimals));

    assertEq(userData.length, 2);
    assertEq(userData[0].index, 0);
    assertEq(userData[1].index, 0);

    assertEq(userData[0].accrued, 0);
    assertEq(userData[1].accrued, 0);

    skip(1);

    // user data should not be updated after asset update
    rewardsController.updateAsset(address(stakeWith18Decimals));

    (rewards, userData) = rewardsController.getUserDataByAsset(address(stakeWith18Decimals), user);

    assertEq(rewards.length, 2);
    assertEq(rewards[0], address(reward18Decimals));
    assertEq(rewards[1], address(reward6Decimals));

    assertEq(userData.length, 2);
    assertEq(userData[0].index, 0);
    assertEq(userData[1].index, 0);

    assertEq(userData[0].accrued, 0);
    assertEq(userData[1].accrued, 0);

    // user data should be updated after asset and user update
    vm.startPrank(user);
    stakeWith18Decimals.transfer(someone, 1);
    vm.stopPrank();

    (rewards, userData) = rewardsController.getUserDataByAsset(address(stakeWith18Decimals), user);

    assertEq(rewards.length, 2);
    assertEq(rewards[0], address(reward18Decimals));
    assertEq(rewards[1], address(reward6Decimals));

    assertEq(userData.length, 2);
    assertGt(userData[0].index, 0);
    assertGt(userData[1].index, 0);

    assertGt(userData[0].accrued, 0);
    assertGt(userData[1].accrued, 0);
  }

  function test_getUserDataByReward() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    IRewardsStructs.UserDataExternal memory userData;

    // uninitialized asset
    userData = rewardsController.getUserDataByReward(
      address(stakeWith6Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(userData.index, 0);
    assertEq(userData.accrued, 0);

    // initialized asset and uninitialized reward
    userData = rewardsController.getUserDataByReward(
      address(stakeWith6Decimals),
      address(unusedReward),
      user
    );

    assertEq(userData.index, 0);
    assertEq(userData.accrued, 0);

    // initialized asset, user data isn't updated
    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(userData.index, 0);
    assertEq(userData.accrued, 0);

    skip(1);

    // user data should not be updated after asset update
    rewardsController.updateAsset(address(stakeWith18Decimals));

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(userData.index, 0);
    assertEq(userData.accrued, 0);

    // user data should be updated after asset and user update
    vm.startPrank(user);
    stakeWith18Decimals.transfer(someone, 1);
    vm.stopPrank();

    userData = rewardsController.getUserDataByReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertGt(userData.index, 0);
    assertGt(userData.accrued, 0);
  }

  function test_calculateRewardIndexes() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    address[] memory rewards;
    uint256[] memory indexes;

    // uninitialized asset and rewards
    (rewards, indexes) = rewardsController.calculateRewardIndexes(address(stakeWith6Decimals));

    assertEq(rewards.length, 0);
    assertEq(indexes.length, 0);

    // initialized asset and initialized reward
    (rewards, indexes) = rewardsController.calculateRewardIndexes(address(stakeWith18Decimals));

    assertEq(rewards.length, 2);
    assertEq(indexes.length, 2);

    assertEq(rewards[0], address(reward18Decimals));
    assertEq(rewards[1], address(reward6Decimals));

    assertEq(indexes[0], 0);
    assertEq(indexes[1], 0);

    skip(1);

    rewardsController.updateAsset(address(stakeWith18Decimals));

    // initialized asset and initialized reward
    (rewards, indexes) = rewardsController.calculateRewardIndexes(address(stakeWith18Decimals));

    assertEq(rewards.length, 2);
    assertEq(indexes.length, 2);

    assertEq(rewards[0], address(reward18Decimals));
    assertEq(rewards[1], address(reward6Decimals));

    assertGt(indexes[0], 0);
    assertGt(indexes[1], 0);
  }

  function test_calculateRewardIndex() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    // uninitialized asset and reward
    uint256 currentRewardIndex = rewardsController.calculateRewardIndex(
      address(stakeWith6Decimals),
      address(unusedReward)
    );
    assertEq(currentRewardIndex, 0);

    // initialized asset and uninitialized reward
    currentRewardIndex = rewardsController.calculateRewardIndex(
      address(stakeWith18Decimals),
      address(unusedReward)
    );
    assertEq(currentRewardIndex, 0);

    // initialized asset and initialized reward but time delta is zero
    currentRewardIndex = rewardsController.calculateRewardIndex(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertEq(currentRewardIndex, 0);

    // initialized asset and initialized reward but time delta is zero
    currentRewardIndex = rewardsController.calculateRewardIndex(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentRewardIndex, 0);

    skip(1);

    rewardsController.updateAsset(address(stakeWith18Decimals));

    // initialized asset and initialized reward
    currentRewardIndex = rewardsController.calculateRewardIndex(
      address(stakeWith18Decimals),
      address(reward18Decimals)
    );
    assertGt(currentRewardIndex, 0);

    // initialized asset and initialized reward
    currentRewardIndex = rewardsController.calculateRewardIndex(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertGt(currentRewardIndex, 0);
  }

  function test_calculateCurrentEmissionScaledReturnZeroData() public {
    // zero liquidity in asset and initialized reward
    uint256 currentEmission = rewardsController.calculateCurrentEmissionScaled(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 0);

    // initialized asset and uninitialized reward
    currentEmission = rewardsController.calculateCurrentEmissionScaled(
      address(stakeWith18Decimals),
      address(unusedReward)
    );
    assertEq(currentEmission, 0);

    // uninitialized asset and reward initialized for another asset
    currentEmission = rewardsController.calculateCurrentEmissionScaled(
      address(stakeWith6Decimals),
      address(reward18Decimals)
    );
    assertEq(currentEmission, 0);

    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(2 * 365 days + 1);

    // already disabled reward emission
    currentEmission = rewardsController.calculateCurrentEmissionScaled(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 0);
  }

  function test_calculateCurrentEmissionScaledReturnNonZero() public {
    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    // current emission less than 1 token
    uint256 currentEmission = rewardsController.calculateCurrentEmissionScaled(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 750000000000);

    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    currentEmission = rewardsController.calculateCurrentEmissionScaled(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 1e12);
  }

  function test_calculateCurrentEmissionReturnZeroData() public {
    // zero liquidity in asset and initialized reward
    uint256 currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 0);

    // uninitialized asset and rewards
    currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith6Decimals),
      address(unusedReward)
    );
    assertEq(currentEmission, 0);

    // initialized asset and uninitialized reward
    currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(unusedReward)
    );
    assertEq(currentEmission, 0);

    // uninitialized asset and reward initialized for another asset
    currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith6Decimals),
      address(unusedReward)
    );
    assertEq(currentEmission, 0);

    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(2 * 365 days + 1);

    // already disabled reward emission
    currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 0);
  }

  function test_calculateCurrentEmissionReturnNonZero() public {
    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    // current emission less than 1 token
    uint256 currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 0);

    _dealStakeToken(stakeWith18Decimals, user, 5_000_000 * 1e18);

    currentEmission = rewardsController.calculateCurrentEmission(
      address(stakeWith18Decimals),
      address(reward6Decimals)
    );
    assertEq(currentEmission, 1);
  }

  function test_calculateCurrentUserRewardsReturnZeroData() public view {
    address[] memory allRewards = rewardsController.getAllRewards(address(stakeWith18Decimals));

    address[] memory rewards;
    uint256[] memory accrued;

    // without deposit
    (rewards, accrued) = rewardsController.calculateCurrentUserRewards(
      address(stakeWith18Decimals),
      user
    );

    assertEq(rewards.length, accrued.length);

    for (uint256 i; i < rewards.length; ++i) {
      assertEq(allRewards[i], rewards[i]);
      assertEq(accrued[i], 0);
    }

    // uninitialized StakeToken
    (rewards, accrued) = rewardsController.calculateCurrentUserRewards(
      address(stakeWith6Decimals),
      user
    );

    assertEq(rewards.length, 0);
    assertEq(accrued.length, 0);
  }

  function test_calculateCurrentUserRewardsReturnFreshData() public {
    address[] memory allRewards = rewardsController.getAllRewards(address(stakeWith18Decimals));

    address[] memory rewards;
    uint256[] memory accrued;

    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    (rewards, accrued) = rewardsController.calculateCurrentUserRewards(
      address(stakeWith18Decimals),
      user
    );

    assertEq(rewards.length, accrued.length);

    for (uint256 i; i < rewards.length; ++i) {
      assertEq(allRewards[i], rewards[i]);
    }

    assertEq(accrued[0], 365 days * 1e12);
    assertEq(accrued[1], 365 days * 1);

    // rewards will be disabled after 2 years from the start, here we skip 2 years + 1
    skip(365 days + 1);

    (rewards, accrued) = rewardsController.calculateCurrentUserRewards(
      address(stakeWith18Decimals),
      user
    );

    assertEq(rewards.length, accrued.length);

    for (uint256 i; i < rewards.length; ++i) {
      assertEq(allRewards[i], rewards[i]);
    }

    assertEq(accrued[0], 2 * 365 days * 1e12);
    assertEq(accrued[1], 2 * 365 days * 1);

    vm.startPrank(user);

    rewardsController.claimAllRewards(address(stakeWith18Decimals), user);

    (rewards, accrued) = rewardsController.calculateCurrentUserRewards(
      address(stakeWith18Decimals),
      user
    );

    for (uint256 i; i < rewards.length; ++i) {
      assertEq(allRewards[i], rewards[i]);
      assertEq(accrued[i], 0);
    }
  }

  function test_calculateCurrentUserRewardReturnZeroData() public view {
    // without deposit - so, any user address
    uint256 accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(accrued, 0);

    // uninitialized asset and reward initialized for another asset
    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith6Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(accrued, 0);

    // initialized asset and uninitialized reward
    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(unusedReward),
      user
    );

    assertEq(accrued, 0);
  }

  function test_calculateCurrentUserRewardReturnFreshData() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    uint256 accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(accrued, 365 days * 1e12);

    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward6Decimals),
      user
    );

    assertEq(accrued, 365 days * 1);

    // rewards will be disabled after 2 years from the start, here we skip 2 years + 1
    skip(365 days + 1);

    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(accrued, 2 * 365 days * 1e12);

    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward6Decimals),
      user
    );

    assertEq(accrued, 2 * 365 days * 1);

    vm.startPrank(user);

    rewardsController.claimAllRewards(address(stakeWith18Decimals), user);

    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward6Decimals),
      user
    );

    assertEq(accrued, 0);

    accrued = rewardsController.calculateCurrentUserReward(
      address(stakeWith18Decimals),
      address(reward18Decimals),
      user
    );

    assertEq(accrued, 0);
  }
}
