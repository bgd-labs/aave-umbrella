// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';

import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';

import {AccessControlUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol';

import {RewardsControllerBaseTest, StakeToken, IRewardsDistributor, IRewardsController, IRewardsStructs} from './utils/RewardsControllerBase.t.sol';

contract RewardsDistributorTest is RewardsControllerBaseTest {
  bytes32 private constant CLAIM_ALL_MULTIPLE_ASSETS_TYPEHASH =
    keccak256(
      'claimAllRewards(address[] assets,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
    );

  bytes32 private constant CLAIM_SELECTED_MULTIPLE_ASSETS_TYPEHASH =
    keccak256(
      'claimSelectedRewards(address[] assets,address[][] rewards,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
    );

  bytes32 private constant TYPE_HASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

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
      reward: address(unusedReward),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1e12,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      rewards
    );

    rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: address(reward6Decimals),
      rewardPayer: address(rewardsAdmin),
      maxEmissionPerSecond: 1 wei,
      distributionEnd: (block.timestamp + 2 * 365 days)
    });

    rewardsController.configureAssetWithRewards(
      address(stakeWith6Decimals),
      10_000_000 * 1e6,
      rewards
    );

    vm.stopPrank();
    vm.startPrank(rewardsAdmin);

    _dealUnderlying(address(reward18Decimals), rewardsAdmin, 2 * 365 days * 1e12);
    _dealUnderlying(address(unusedReward), rewardsAdmin, 2 * 365 days * 1e12);
    _dealUnderlying(address(reward6Decimals), rewardsAdmin, 2 * 365 days * 1);

    reward18Decimals.approve(address(rewardsController), 2 * 365 days * 1e12);
    unusedReward.approve(address(rewardsController), 2 * 365 days * 1e12);
    reward6Decimals.approve(address(rewardsController), 2 * 365 days * 1);
  }

  function test_claimAllRewardsByUser() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkNonZeroReward(stakeWith6Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(user);

    address[] memory assets = new address[](2);

    assets[0] = address(stakeWith18Decimals);
    assets[1] = address(stakeWith6Decimals);

    (address[][] memory addresses, uint256[][] memory amounts) = rewardsController.claimAllRewards(
      assets,
      someone
    );

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(unusedReward.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    assertEq(amounts[0][0], 365 days * 1e12);
    assertEq(amounts[0][1], 365 days * 1e12);
    assertEq(amounts[1][0], 365 days * 1);

    assertEq(addresses[0][0], address(reward18Decimals));
    assertEq(addresses[0][1], address(unusedReward));
    assertEq(addresses[1][0], address(reward6Decimals));

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkZeroReward(stakeWith6Decimals, address(reward6Decimals), user);
  }

  function test_claimAllRewardsByUserInvalidAssets() public {
    vm.startPrank(user);

    address[] memory assets = new address[](2);

    assets[0] = address(new StakeToken(rewardsController));
    assets[1] = address(new StakeToken(rewardsController));

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsController.AssetNotInitialized.selector, assets[0])
    );
    rewardsController.claimAllRewards(assets, someone);
  }

  function test_claimAllRewardsByClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkNonZeroReward(stakeWith6Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(user);

    rewardsController.setClaimer(someone, true);

    vm.stopPrank();
    vm.startPrank(someone);

    address[] memory assets = new address[](2);

    assets[0] = address(stakeWith18Decimals);
    assets[1] = address(stakeWith6Decimals);

    (address[][] memory addresses, uint256[][] memory amounts) = rewardsController
      .claimAllRewardsOnBehalf(assets, user, someone);

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(unusedReward.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    assertEq(amounts[0][0], 365 days * 1e12);
    assertEq(amounts[0][1], 365 days * 1e12);
    assertEq(amounts[1][0], 365 days * 1);

    assertEq(addresses[0][0], address(reward18Decimals));
    assertEq(addresses[0][1], address(unusedReward));
    assertEq(addresses[1][0], address(reward6Decimals));

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkZeroReward(stakeWith6Decimals, address(reward6Decimals), user);
  }

  function test_claimAllRewardsByNotClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkNonZeroReward(stakeWith6Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.stopPrank();
    vm.startPrank(someone);

    address[] memory assets = new address[](2);

    assets[0] = address(stakeWith18Decimals);
    assets[1] = address(stakeWith6Decimals);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.ClaimerNotAuthorized.selector, someone, user)
    );
    rewardsController.claimAllRewardsOnBehalf(assets, user, someone);
  }

  function test_claimSelectedRewardsByUser() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkNonZeroReward(stakeWith6Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(user);

    address[] memory assets = new address[](2);

    {
      assets[0] = address(stakeWith18Decimals);
      assets[1] = address(stakeWith6Decimals);
    }

    address[][] memory rewards = new address[][](2);

    {
      rewards[0] = new address[](2);
      rewards[1] = new address[](1);

      rewards[0][0] = address(reward18Decimals);
      rewards[0][1] = address(unusedReward);
      rewards[1][0] = address(reward6Decimals);
    }

    uint256[][] memory amounts = rewardsController.claimSelectedRewards(assets, rewards, someone);

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(unusedReward.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    assertEq(amounts[0][0], 365 days * 1e12);
    assertEq(amounts[0][1], 365 days * 1e12);
    assertEq(amounts[1][0], 365 days * 1);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkZeroReward(stakeWith6Decimals, address(reward6Decimals), user);
  }

  function test_claimSelectedRewardsByUserWontRevertWithInvalidReward() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    vm.startPrank(user);

    address[] memory assets = new address[](2);

    {
      assets[0] = address(stakeWith18Decimals);
      assets[1] = address(stakeWith6Decimals);
    }

    address[][] memory rewards = new address[][](2);

    {
      rewards[0] = new address[](2);
      rewards[1] = new address[](1);

      rewards[0][0] = address(underlying18Decimals);
      rewards[0][1] = address(underlying18Decimals);
      rewards[1][0] = address(underlying6Decimals);
    }

    uint256[][] memory amounts = rewardsController.claimSelectedRewards(assets, rewards, someone);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    assertEq(amounts[0][0], 0);
    assertEq(amounts[0][1], 0);
    assertEq(amounts[1][0], 0);
  }

  function test_claimSelectedRewardsByClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkNonZeroReward(stakeWith6Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(user);

    address[] memory assets = new address[](2);

    {
      assets[0] = address(stakeWith18Decimals);
      assets[1] = address(stakeWith6Decimals);
    }

    address[][] memory rewards = new address[][](2);

    {
      rewards[0] = new address[](2);
      rewards[1] = new address[](1);

      rewards[0][0] = address(reward18Decimals);
      rewards[0][1] = address(unusedReward);
      rewards[1][0] = address(reward6Decimals);
    }

    rewardsController.setClaimer(someone, true);

    vm.stopPrank();
    vm.startPrank(someone);

    uint256[][] memory amounts = rewardsController.claimSelectedRewardsOnBehalf(
      assets,
      rewards,
      user,
      someone
    );

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(unusedReward.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    assertEq(amounts[0][0], 365 days * 1e12);
    assertEq(amounts[0][1], 365 days * 1e12);
    assertEq(amounts[1][0], 365 days * 1);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkZeroReward(stakeWith6Decimals, address(reward6Decimals), user);
  }

  function test_claimSelectedRewardsByNotClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);
    _dealStakeToken(stakeWith6Decimals, user, 10_000_000 * 1e6);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(unusedReward), user);
    _checkNonZeroReward(stakeWith6Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(unusedReward.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(user);

    address[] memory assets = new address[](2);

    {
      assets[0] = address(stakeWith18Decimals);
      assets[1] = address(stakeWith6Decimals);
    }

    address[][] memory rewards = new address[][](2);

    {
      rewards[0] = new address[](2);
      rewards[1] = new address[](1);

      rewards[0][0] = address(reward18Decimals);
      rewards[0][1] = address(unusedReward);
      rewards[1][0] = address(reward6Decimals);
    }

    vm.stopPrank();
    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.ClaimerNotAuthorized.selector, someone, user)
    );
    rewardsController.claimSelectedRewardsOnBehalf(assets, rewards, user, someone);
  }

  function _checkNonZeroReward(StakeToken asset, address reward, address user) internal view {
    assertGt(rewardsController.calculateCurrentUserReward(address(asset), reward, user), 0);
  }

  function _checkZeroReward(StakeToken asset, address reward, address user) internal view {
    assertEq(rewardsController.calculateCurrentUserReward(address(asset), reward, user), 0);
  }
}
