// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IUmbrellaBatchHelper} from '../../src/contracts/helpers/interfaces/IUmbrellaBatchHelper.sol';
import {IStakeToken} from '../../src/contracts/stakeToken/interfaces/IStakeToken.sol';

import {UmbrellaBatchHelperTestBase} from './utils/UmbrellaBatchHelperBase.t.sol';

contract UmbrellaTokenHelper is UmbrellaBatchHelperTestBase {
  function test_initializeSomeStakeTokens() public {
    mockRewardsController.registerToken(address(stakeToken));
    mockRewardsController.registerToken(address(stakeTokenWithoutStata));

    IStakeToken[] memory stakes = new IStakeToken[](1);
    stakes[0] = IStakeToken(address(stakeToken));

    vm.expectEmit();
    emit IUmbrellaBatchHelper.AssetPathInitialized(address(stakeToken));

    umbrellaBatchHelper.initializePath(stakes);

    stakes[0] = IStakeToken(address(stakeTokenWithoutStata));

    vm.expectEmit();
    emit IUmbrellaBatchHelper.AssetPathInitialized(address(stakeTokenWithoutStata));

    umbrellaBatchHelper.initializePath(stakes);
  }

  function test_initializationShouldRevert() public {
    IStakeToken[] memory stakes = new IStakeToken[](1);
    stakes[0] = IStakeToken(address(tokenAddressesWithStata[1]));

    // not initialized asset
    stakes[0] = IStakeToken(address(stakeToken));

    vm.expectRevert(abi.encodeWithSelector(IUmbrellaBatchHelper.NotInitializedStake.selector));
    umbrellaBatchHelper.initializePath(stakes);

    // not initialized asset
    stakes[0] = IStakeToken(address(stakeTokenWithoutStata));

    vm.expectRevert(abi.encodeWithSelector(IUmbrellaBatchHelper.NotInitializedStake.selector));
    umbrellaBatchHelper.initializePath(stakes);
  }

  function test_batchSomeTokensPermits(uint256 amount) public {
    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    // 3 not 4 cause Weth doesn't have EIP712
    bytes[] memory bytesArray = new bytes[](3);

    for (uint256 i; i < 3; ++i) {
      bytes32 hash = getHash(user, spender, tokenAddressesWithStata[i], amount, 0, deadline);
      (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

      bytesArray[i] = abi.encodeWithSelector(
        IUmbrellaBatchHelper.permit.selector,
        IUmbrellaBatchHelper.Permit({
          token: tokenAddressesWithStata[i],
          value: amount,
          deadline: deadline,
          v: v,
          r: r,
          s: s
        })
      );
    }
    for (uint256 i; i < 3; ++i) {
      assertEq(IERC20(tokenAddressesWithStata[i]).allowance(user, spender), 0);
    }

    vm.startPrank(user);

    umbrellaBatchHelper.multicall(bytesArray);

    for (uint256 i; i < 3; ++i) {
      assertEq(IERC20(tokenAddressesWithStata[i]).allowance(user, spender), amount);
    }
  }

  function test_batchSomeTokensPermitsFrontRunSignature(uint256 amount) public {
    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    // 3 not 4 cause Weth doesn't have EIP712
    bytes[] memory batch = new bytes[](3);
    IUmbrellaBatchHelper.Permit[] memory copy = new IUmbrellaBatchHelper.Permit[](3);

    for (uint256 i; i < 3; ++i) {
      bytes32 hash = getHash(user, spender, tokenAddressesWithStata[i], amount, 0, deadline);
      (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

      copy[i] = IUmbrellaBatchHelper.Permit({
        token: tokenAddressesWithStata[i],
        value: amount,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      });

      batch[i] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, copy[i]);
    }

    vm.startPrank(attacker);

    for (uint256 i; i < 3; ++i) {
      IERC20Permit(tokenAddressesWithStata[i]).permit(
        user,
        spender,
        amount,
        deadline,
        copy[i].v,
        copy[i].r,
        copy[i].s
      );
    }

    for (uint256 i; i < 3; ++i) {
      assertEq(IERC20(tokenAddressesWithStata[i]).allowance(user, spender), amount);
    }

    vm.stopPrank();
    vm.startPrank(user);

    // shouldn't revert, just catch some errors
    umbrellaBatchHelper.multicall(batch);

    // result is the same
    for (uint256 i; i < 3; ++i) {
      assertEq(IERC20(tokenAddressesWithStata[i]).allowance(user, spender), amount);
    }
  }

  function test_batchCooldownPermits(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));
    mockRewardsController.registerToken(address(stakeTokenWithoutStata));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealStakeToken(user, address(stakeToken), amount);
    _dealStakeToken(user, address(stakeTokenWithoutStata), amount);

    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.CooldownPermit[]
      memory permitCooldowns = new IUmbrellaBatchHelper.CooldownPermit[](2);

    // Permit only stakeTokens
    bytes32 hash = getHashCooldownWithPermit(
      tokenAddressesWithStata[0],
      user,
      address(umbrellaBatchHelper),
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permitCooldowns[0] = IUmbrellaBatchHelper.CooldownPermit({
      stakeToken: IStakeToken(tokenAddressesWithStata[0]),
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    hash = getHashCooldownWithPermit(
      tokenAddressesWithoutStata[0],
      user,
      address(umbrellaBatchHelper),
      0,
      deadline
    );
    (v, r, s) = signHash(userPrivateKey, hash);

    permitCooldowns[1] = IUmbrellaBatchHelper.CooldownPermit({
      stakeToken: IStakeToken(tokenAddressesWithoutStata[0]),
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.cooldownPermit.selector,
      permitCooldowns[0]
    );
    batch[1] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.cooldownPermit.selector,
      permitCooldowns[1]
    );

    IStakeToken.CooldownSnapshot memory snapshotBefore = stakeToken.getStakerCooldown(user);

    assertEq(snapshotBefore.amount, 0);
    assertEq(snapshotBefore.endOfCooldown, 0);
    assertEq(snapshotBefore.withdrawalWindow, 0);

    snapshotBefore = stakeTokenWithoutStata.getStakerCooldown(user);

    assertEq(snapshotBefore.amount, 0);
    assertEq(snapshotBefore.endOfCooldown, 0);
    assertEq(snapshotBefore.withdrawalWindow, 0);

    vm.startPrank(user);

    umbrellaBatchHelper.multicall(batch);

    IStakeToken.CooldownSnapshot memory snapshotAfter = stakeToken.getStakerCooldown(user);

    assertEq(snapshotAfter.amount, amount);
    assertEq(snapshotAfter.endOfCooldown, block.timestamp + stakeToken.getCooldown());
    assertEq(snapshotAfter.withdrawalWindow, stakeToken.getUnstakeWindow());

    snapshotAfter = stakeTokenWithoutStata.getStakerCooldown(user);

    assertEq(snapshotAfter.amount, amount);
    assertEq(snapshotAfter.endOfCooldown, block.timestamp + stakeTokenWithoutStata.getCooldown());
    assertEq(snapshotAfter.withdrawalWindow, stakeTokenWithoutStata.getUnstakeWindow());
  }

  function test_batchCooldownPermitsInvalidSigReverts(uint96 amount) public {
    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealStakeToken(user, address(stakeToken), amount);

    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.CooldownPermit[]
      memory permitCooldowns = new IUmbrellaBatchHelper.CooldownPermit[](1);

    // Permit only stakeTokens
    bytes32 hash = getHashCooldownWithPermit(
      tokenAddressesWithStata[0],
      user,
      address(umbrellaBatchHelper),
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(someonePrivateKey, hash);

    permitCooldowns[0] = IUmbrellaBatchHelper.CooldownPermit({
      stakeToken: IStakeToken(tokenAddressesWithStata[0]),
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.cooldownPermit.selector,
      permitCooldowns[0]
    );

    vm.startPrank(user);

    vm.expectRevert();
    umbrellaBatchHelper.multicall(batch);
  }

  function test_batchHelperDepositFromWeth(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeTokenWithWeth));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealUnderlyingToken(user, address(stakeToken), amount); // same underlying token as in stakeToken

    address spender = address(umbrellaBatchHelper);

    vm.startPrank(user);

    IERC20(underlying).approve(spender, amount);

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeTokenWithWeth)),
      edgeToken: underlying,
      value: amount
    });

    bytes[] memory batch = new bytes[](1);

    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[0]);

    assertEq(stakeTokenWithWeth.balanceOf(user), 0);

    umbrellaBatchHelper.multicall(batch);

    assertEq(stakeTokenWithWeth.balanceOf(user), amount);

    checkHelperBalancesAfterActions();
  }

  function test_batchHelperDepositFromToken(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));
    mockRewardsController.registerToken(address(stakeTokenWithoutStata));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealUnderlyingToken(user, address(stakeToken), amount);
    _dealUnderlyingToken(user, address(stakeTokenWithoutStata), amount);

    address spender = address(umbrellaBatchHelper);

    vm.startPrank(user);

    // WETH don't have permit
    IERC20(underlying).approve(spender, amount);
    IERC20(nonStataUnderlying).approve(spender, amount);

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](2);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: underlying,
      value: amount
    });
    actions[1] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
      edgeToken: address(nonStataUnderlying),
      value: amount
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[1]);

    assertEq(stakeTokenWithoutStata.balanceOf(user), 0);
    assertEq(stakeToken.balanceOf(user), 0);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(stakeToken.balanceOf(user), amount);
    assertEq(stakeTokenWithoutStata.balanceOf(user), amount);

    checkHelperBalancesAfterActions();
  }

  function test_batchHelperDepositFromAToken(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealAToken(user, amount);

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[2], amount, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[2],
      value: amount,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    vm.startPrank(user);

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    assertEq(stakeToken.balanceOf(user), 0);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[2],
      value: amount
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[0]);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(stakeToken.balanceOf(user), amount);
    checkHelperBalancesAfterActions();
  }

  function test_batchHelperDepositFromStataToken(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealStataToken(user, amount);

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[1], amount, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[1],
      value: amount,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    vm.startPrank(user);

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    assertEq(stakeToken.balanceOf(user), 0);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[1],
      value: amount
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[0]);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(stakeToken.balanceOf(user), amount);
    checkHelperBalancesAfterActions();
  }

  function test_batchHelperWithdrawToToken(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));
    mockRewardsController.registerToken(address(stakeTokenWithoutStata));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealStakeToken(user, address(stakeToken), amount);
    _dealStakeToken(user, address(stakeTokenWithoutStata), amount);

    vm.startPrank(user);

    stakeToken.cooldown();
    stakeTokenWithoutStata.cooldown();

    skip(stakeToken.getCooldown());

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](2);

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[0], amount, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[0],
      value: amount,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    hash = getHash(user, spender, tokenAddressesWithoutStata[0], amount, 0, deadline);
    (v, r, s) = signHash(userPrivateKey, hash);

    permits[1] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithoutStata[0],
      value: amount,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](2);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: underlying,
      value: amount
    });

    actions[1] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
      edgeToken: address(nonStataUnderlying),
      value: amount
    });

    bytes[] memory batch = new bytes[](4);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[1]);

    batch[2] = abi.encodeWithSelector(IUmbrellaBatchHelper.redeem.selector, actions[0]);
    batch[3] = abi.encodeWithSelector(IUmbrellaBatchHelper.redeem.selector, actions[1]);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(IERC20(underlying).balanceOf(user), amount);
    assertEq(IERC20(nonStataUnderlying).balanceOf(user), amount);

    checkHelperBalancesAfterActions();
  }

  function test_batchHelperWithdrawToAToken(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealStakeToken(user, address(stakeToken), amount);

    vm.startPrank(user);

    stakeToken.cooldown();
    skip(stakeToken.getCooldown());

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[0], amount, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[0],
      value: amount,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[2],
      value: amount
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.redeem.selector, actions[0]);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(IERC20(aToken).balanceOf(user), amount);

    checkHelperBalancesAfterActions();
  }

  function test_batchHelperWithdrawToStataToken(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealStakeToken(user, address(stakeToken), amount);

    vm.startPrank(user);

    stakeToken.cooldown();
    skip(stakeToken.getCooldown());

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[0], amount, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[0],
      value: amount,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[1],
      value: amount
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.redeem.selector, actions[0]);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(IERC20(stataTokenV2).balanceOf(user), amount);

    checkHelperBalancesAfterActions();
  }

  function test_depositNotRelatedTokenShouldRevert() public {
    mockRewardsController.registerToken(address(stakeToken));

    _dealStakeToken(user, address(stakeToken), 1e18);

    vm.startPrank(user);

    stakeToken.cooldown();
    skip(stakeToken.getCooldown());

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[0], 1e18, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[0],
      value: 1e18,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithoutStata[1],
      value: 1e18
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.redeem.selector, actions[0]);

    vm.expectRevert(abi.encodeWithSelector(IUmbrellaBatchHelper.InvalidEdgeToken.selector));
    umbrellaBatchHelper.multicall(batch);
  }
}
