// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IUmbrellaStakeToken} from '../../src/contracts/stakeToken/interfaces/IUmbrellaStakeToken.sol';
import {IUmbrellaBatchHelper} from '../../src/contracts/helpers/interfaces/IUmbrellaBatchHelper.sol';

import {UmbrellaBatchHelperWithRewardsTestBase, TransparentUpgradeableProxy} from './utils/UmbrellaBatchHelperWithRewardsBase.t.sol';
import {MockERC20} from './utils/mocks/MockERC20.sol';

import {RewardsController, IRewardsController} from '../../src/contracts/rewards/RewardsController.sol';
import {UmbrellaBatchHelper} from '../../src/contracts/helpers/UmbrellaBatchHelper.sol';

contract UmbrellaTokenHelperWithRewards is UmbrellaBatchHelperWithRewardsTestBase {
  function test_claimRewardsStata() public {
    IUmbrellaBatchHelper.ClaimPermit[] memory claimPermits = new IUmbrellaBatchHelper.ClaimPermit[](
      1
    );

    address sender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    address[] memory rewards = new address[](3);

    rewards[0] = address(tokenAddressesWithStata[2]); // aToken
    rewards[1] = address(tokenAddressesWithStata[3]); // underlying (reward should be zero)
    rewards[2] = address(unusedRewardToken); // unused Reward Token

    bytes32 hash = getHashClaimSelectedWithPermit(
      address(stakeToken),
      rewards,
      user,
      user,
      sender,
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    claimPermits[0] = IUmbrellaBatchHelper.ClaimPermit({
      stakeToken: IUmbrellaStakeToken(address(stakeToken)),
      rewards: rewards,
      deadline: deadline,
      v: v,
      r: r,
      s: s,
      restake: false
    });

    vm.startPrank(user);

    for (uint256 i; i < rewards.length; ++i) {
      assertEq(IERC20(rewards[i]).balanceOf(user), 0);
    }

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.claimRewardsPermit.selector,
      claimPermits[0]
    );
    umbrellaBatchHelper.multicall(batch);

    rewards = new address[](2);

    rewards[0] = address(tokenAddressesWithStata[2]); // aToken
    rewards[1] = address(unusedRewardToken);

    for (uint256 i; i < rewards.length; ++i) {
      assertNotEq(IERC20(rewards[i]).balanceOf(user), 0);
    }

    assertEq(IERC20(tokenAddressesWithStata[3]).balanceOf(user), 0); // underlying (reward should be zero)
  }

  function test_claimRewardsWithoutStata() public {
    IUmbrellaBatchHelper.ClaimPermit[] memory claimPermits = new IUmbrellaBatchHelper.ClaimPermit[](
      1
    );
    address sender = address(umbrellaBatchHelper);
    address receiver = user;
    uint256 deadline = (block.timestamp + 1e6);

    address[] memory rewards = new address[](1);

    rewards[0] = address(tokenAddressesWithoutStata[1]); // Token

    bytes32 hash = getHashClaimSelectedWithPermit(
      address(stakeTokenWithoutStata),
      rewards,
      user,
      receiver,
      sender,
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    claimPermits[0] = IUmbrellaBatchHelper.ClaimPermit({
      stakeToken: IUmbrellaStakeToken(address(stakeTokenWithoutStata)),
      rewards: rewards,
      deadline: deadline,
      v: v,
      r: r,
      s: s,
      restake: false
    });

    vm.startPrank(user);

    for (uint256 i; i < rewards.length; ++i) {
      assertEq(IERC20(rewards[i]).balanceOf(user), 0);
    }

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.claimRewardsPermit.selector,
      claimPermits[0]
    );
    umbrellaBatchHelper.multicall(batch);

    for (uint256 i; i < rewards.length; ++i) {
      assertNotEq(IERC20(rewards[i]).balanceOf(user), 0);
    }
  }

  function test_restakeRewardsStata() public {
    IUmbrellaBatchHelper.ClaimPermit[] memory claimPermits = new IUmbrellaBatchHelper.ClaimPermit[](
      1
    );

    address sender = address(umbrellaBatchHelper);
    address receiver = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    address[] memory rewards = new address[](3);

    rewards[0] = address(tokenAddressesWithStata[2]); // aToken (should be restaked)
    rewards[1] = address(tokenAddressesWithStata[3]); // underlying (reward should be zero)
    rewards[2] = address(unusedRewardToken); // unused Reward Token

    bytes32 hash = getHashClaimSelectedWithPermit(
      address(stakeToken),
      rewards,
      user,
      receiver,
      sender,
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    receiver = user;

    claimPermits[0] = IUmbrellaBatchHelper.ClaimPermit({
      stakeToken: IUmbrellaStakeToken(address(stakeToken)),
      rewards: rewards,
      deadline: deadline,
      v: v,
      r: r,
      s: s,
      restake: true
    });

    vm.startPrank(user);

    uint256 amount = stakeToken.balanceOf(user);
    assertNotEq(amount, 0);

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.claimRewardsPermit.selector,
      claimPermits[0]
    );
    umbrellaBatchHelper.multicall(batch);

    assertNotEq(IERC20(unusedRewardToken).balanceOf(user), 0); // unused Reward Token

    assertEq(IERC20(tokenAddressesWithStata[2]).balanceOf(user), 0); // aToken (should be restaked)
    assertEq(IERC20(tokenAddressesWithStata[3]).balanceOf(user), 0); // underlying (reward should be zero)

    assertGt(stakeToken.balanceOf(user), amount);
  }

  function test_restakeRewardsWithoutStata() public {
    IUmbrellaBatchHelper.ClaimPermit[] memory claimPermits = new IUmbrellaBatchHelper.ClaimPermit[](
      1
    );

    address sender = address(umbrellaBatchHelper);
    address receiver = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    address[] memory rewards = new address[](1);

    rewards[0] = address(tokenAddressesWithoutStata[1]); // Token

    bytes32 hash = getHashClaimSelectedWithPermit(
      address(stakeTokenWithoutStata),
      rewards,
      user,
      receiver,
      sender,
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    claimPermits[0] = IUmbrellaBatchHelper.ClaimPermit({
      stakeToken: IUmbrellaStakeToken(address(stakeTokenWithoutStata)),
      rewards: rewards,
      deadline: deadline,
      v: v,
      r: r,
      s: s,
      restake: true
    });

    vm.startPrank(user);

    assertEq(IERC20(tokenAddressesWithoutStata[1]).balanceOf(user), 0);

    uint256 amount = stakeTokenWithoutStata.balanceOf(user);
    assertNotEq(amount, 0);

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.claimRewardsPermit.selector,
      claimPermits[0]
    );
    umbrellaBatchHelper.multicall(batch);

    assertEq(IERC20(tokenAddressesWithoutStata[1]).balanceOf(user), 0);
    assertGt(stakeTokenWithoutStata.balanceOf(user), amount);
  }
}
