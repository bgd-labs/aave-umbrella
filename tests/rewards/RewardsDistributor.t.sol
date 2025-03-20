// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';

import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';

import {AccessControlUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol';

import {RewardsControllerBaseTest, StakeToken, IRewardsDistributor, IRewardsStructs} from './utils/RewardsControllerBase.t.sol';

contract RewardsDistributorTest is RewardsControllerBaseTest {
  bytes32 private constant CLAIM_ALL_TYPEHASH =
    keccak256(
      'ClaimAllRewards(address asset,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
    );

  bytes32 private constant CLAIM_SELECTED_TYPEHASH =
    keccak256(
      'ClaimSelectedRewards(address asset,address[] rewards,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
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

  function test_setClaimer() public {
    vm.startPrank(user);

    rewardsController.setClaimer(someone, true);

    assert(rewardsController.isClaimerAuthorized(user, someone));

    rewardsController.setClaimer(someone, false);

    assertFalse(rewardsController.isClaimerAuthorized(user, someone));
  }

  function test_setClaimerByAdmin() public {
    vm.startPrank(defaultAdmin);

    rewardsController.setClaimer(user, someone, true);

    assert(rewardsController.isClaimerAuthorized(user, someone));

    rewardsController.setClaimer(user, someone, false);

    assertFalse(rewardsController.isClaimerAuthorized(user, someone));
  }

  function test_setClaimerByNonAdmin() public {
    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        address(someone),
        bytes32(0x00)
      )
    );

    rewardsController.setClaimer(user, someone, true);
  }

  function test_claimAllRewardsByUser() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(reward6Decimals), user);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(user);

    rewardsController.claimAllRewards(address(stakeWith18Decimals), someone);

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(reward6Decimals), user);
  }

  function test_claimAllRewardsByClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(reward6Decimals), user);

    vm.startPrank(user);

    rewardsController.setClaimer(someone, true);

    vm.stopPrank();
    vm.startPrank(someone);

    rewardsController.claimAllRewardsOnBehalf(address(stakeWith18Decimals), user, someone);

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(reward6Decimals), user);
  }

  function test_claimAllRewardsByNotClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.ClaimerNotAuthorized.selector, someone, user)
    );
    rewardsController.claimAllRewardsOnBehalf(address(stakeWith18Decimals), user, someone);
  }

  function test_claimAllRewardsUsingSignature() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);
    assertEq(rewardsController.nonces(user), 0);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(reward6Decimals), user);

    uint256 deadline = block.timestamp + 1e6;
    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_ALL_TYPEHASH,
        address(stakeWith18Decimals),
        user,
        someone,
        someone,
        0,
        deadline
      )
    );
    bytes32 hash = _toTypedDataHash(_domainSeparator(), digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
    IRewardsStructs.SignatureParams memory sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    rewardsController.claimAllRewardsPermit(
      address(stakeWith18Decimals),
      user,
      someone,
      deadline,
      sig
    );

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);
    assertEq(rewardsController.nonces(user), 1);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(reward6Decimals), user);
  }

  function test_claimAllRewardsExpiredDeadline() public {
    uint256 deadline = block.timestamp - 1;
    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_ALL_TYPEHASH,
        address(stakeWith18Decimals),
        user,
        someone,
        someone,
        0,
        deadline
      )
    );
    bytes32 hash = _toTypedDataHash(_domainSeparator(), digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
    IRewardsStructs.SignatureParams memory sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.ExpiredSignature.selector, deadline)
    );
    rewardsController.claimAllRewardsPermit(
      address(stakeWith18Decimals),
      user,
      someone,
      deadline,
      sig
    );
  }

  function test_claimAllRewardsInvalidSig() public {
    uint256 deadline = block.timestamp + 1e6;
    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_ALL_TYPEHASH,
        address(stakeWith18Decimals),
        user,
        someone,
        someone,
        0,
        deadline
      )
    );
    bytes32 hash = _toTypedDataHash(_domainSeparator(), digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(someonePrivateKey, hash);
    IRewardsStructs.SignatureParams memory sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.InvalidSigner.selector, someone, user)
    );

    rewardsController.claimAllRewardsPermit(
      address(stakeWith18Decimals),
      user,
      someone,
      deadline,
      sig
    );
  }

  function test_claimSelectedRewardsByUser() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);

    vm.startPrank(user);

    address[] memory rewards = new address[](1);
    rewards[0] = address(reward18Decimals);

    uint256[] memory amounts = rewardsController.claimSelectedRewards(
      address(stakeWith18Decimals),
      rewards,
      someone
    );

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    assertEq(rewards.length, amounts.length);
    assertEq(reward18Decimals.balanceOf(someone), amounts[0]);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
  }

  function test_claimSelectedRewardsByUserWontRevertWithInvalidReward() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    vm.startPrank(user);

    address[] memory rewards = new address[](1);
    rewards[0] = address(unusedReward);

    uint256[] memory amounts = rewardsController.claimSelectedRewards(
      address(stakeWith18Decimals),
      rewards,
      someone
    );

    assertEq(amounts.length, 1);
    assertEq(amounts[0], 0);
  }

  function test_claimSelectedRewardsByClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(reward6Decimals), user);

    vm.startPrank(user);

    rewardsController.setClaimer(someone, true);

    vm.startPrank(someone);

    address[] memory rewards = new address[](1);
    rewards[0] = address(reward18Decimals);

    uint256[] memory amounts = rewardsController.claimSelectedRewardsOnBehalf(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone
    );

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    assertEq(reward18Decimals.balanceOf(someone), amounts[0]);
    assertEq(rewards.length, amounts.length);

    rewards[0] = address(reward6Decimals);

    amounts = rewardsController.claimSelectedRewardsOnBehalf(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone
    );

    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    assertEq(reward6Decimals.balanceOf(someone), amounts[0]);
    assertEq(rewards.length, amounts.length);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(reward6Decimals), user);
  }

  function test_claimSelectedRewardsByNotClaimer() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    vm.startPrank(someone);

    address[] memory rewards = new address[](1);
    rewards[0] = address(reward18Decimals);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.ClaimerNotAuthorized.selector, someone, user)
    );
    rewardsController.claimSelectedRewardsOnBehalf(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone
    );
  }

  function test_claimSelectedRewardsUsingSignature() public {
    _dealStakeToken(stakeWith18Decimals, user, 10_000_000 * 1e18);

    skip(365 days);

    assertEq(reward18Decimals.balanceOf(someone), 0);
    assertEq(reward6Decimals.balanceOf(someone), 0);
    assertEq(rewardsController.nonces(user), 0);

    _checkNonZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkNonZeroReward(stakeWith18Decimals, address(reward6Decimals), user);

    address[] memory rewards = new address[](1);
    rewards[0] = address(reward18Decimals);
    bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));

    uint256 deadline = block.timestamp + 1e6;
    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_SELECTED_TYPEHASH,
        address(stakeWith18Decimals),
        rewardsHash,
        user,
        someone,
        someone,
        0,
        deadline
      )
    );
    bytes32 hash = _toTypedDataHash(_domainSeparator(), digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
    IRewardsStructs.SignatureParams memory sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    uint256[] memory amounts = rewardsController.claimSelectedRewardsPermit(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone,
      deadline,
      sig
    );

    assertEq(reward18Decimals.balanceOf(someone), 365 days * 1e12);
    assertEq(reward6Decimals.balanceOf(someone), 0);

    assertEq(amounts[0], reward18Decimals.balanceOf(someone));
    assertEq(amounts.length, rewards.length);

    assertEq(rewardsController.nonces(user), 1);

    rewards[0] = address(reward6Decimals);
    rewardsHash = keccak256(abi.encodePacked(rewards));

    digest = keccak256(
      abi.encode(
        CLAIM_SELECTED_TYPEHASH,
        address(stakeWith18Decimals),
        rewardsHash,
        user,
        someone,
        someone,
        1,
        deadline
      )
    );
    hash = _toTypedDataHash(_domainSeparator(), digest);

    (v, r, s) = vm.sign(userPrivateKey, hash);
    sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    amounts = rewardsController.claimSelectedRewardsPermit(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone,
      deadline,
      sig
    );

    assertEq(reward6Decimals.balanceOf(someone), 365 days * 1);

    assertEq(amounts[0], reward6Decimals.balanceOf(someone));
    assertEq(amounts.length, rewards.length);

    assertEq(rewardsController.nonces(user), 2);

    _checkZeroReward(stakeWith18Decimals, address(reward18Decimals), user);
    _checkZeroReward(stakeWith18Decimals, address(reward6Decimals), user);
  }

  function test_claimSelectedRewardsExpiredDeadline() public {
    address[] memory rewards = new address[](1);
    rewards[0] = address(reward18Decimals);

    uint256 deadline = block.timestamp - 1;
    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_SELECTED_TYPEHASH,
        address(stakeWith18Decimals),
        rewards,
        user,
        someone,
        someone,
        0,
        deadline
      )
    );
    bytes32 hash = _toTypedDataHash(_domainSeparator(), digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
    IRewardsStructs.SignatureParams memory sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.ExpiredSignature.selector, deadline)
    );

    rewardsController.claimSelectedRewardsPermit(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone,
      deadline,
      sig
    );
  }

  function test_claimSelectedRewardsInvalidSig() public {
    address[] memory rewards = new address[](1);
    rewards[0] = address(reward18Decimals);
    bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));

    uint256 deadline = block.timestamp + 1e6;
    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_SELECTED_TYPEHASH,
        address(stakeWith18Decimals),
        rewardsHash,
        user,
        someone,
        someone,
        0,
        deadline
      )
    );
    bytes32 hash = _toTypedDataHash(_domainSeparator(), digest);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(someonePrivateKey, hash);
    IRewardsStructs.SignatureParams memory sig = IRewardsStructs.SignatureParams(v, r, s);

    vm.startPrank(someone);

    vm.expectRevert(
      abi.encodeWithSelector(IRewardsDistributor.InvalidSigner.selector, someone, user)
    );

    rewardsController.claimSelectedRewardsPermit(
      address(stakeWith18Decimals),
      rewards,
      user,
      someone,
      deadline,
      sig
    );
  }

  function _checkNonZeroReward(StakeToken asset, address reward, address user) internal view {
    assertGt(rewardsController.calculateCurrentUserReward(address(asset), reward, user), 0);
  }

  function _checkZeroReward(StakeToken asset, address reward, address user) internal view {
    assertEq(rewardsController.calculateCurrentUserReward(address(asset), reward, user), 0);
  }

  // copy from OZ
  function _domainSeparator() private view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          TYPE_HASH,
          _hashedName,
          _hashedVersion,
          block.chainid,
          address(rewardsController)
        )
      );
  }

  function _toTypedDataHash(
    bytes32 domainSeparator,
    bytes32 structHash
  ) private pure returns (bytes32 digest) {
    /// @solidity memory-safe-assembly
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, hex'19_01')
      mstore(add(ptr, 0x02), domainSeparator)
      mstore(add(ptr, 0x22), structHash)
      digest := keccak256(ptr, 0x42)
    }
  }
}
