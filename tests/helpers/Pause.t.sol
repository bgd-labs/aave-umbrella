// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {Pausable} from 'openzeppelin-contracts/contracts/utils/Pausable.sol';

import {IStakeToken} from '../../src/contracts/stakeToken/interfaces/IStakeToken.sol';
import {IUmbrellaBatchHelper} from '../../src/contracts/helpers/interfaces/IUmbrellaBatchHelper.sol';

import {UmbrellaBatchHelperTestBase} from './utils/UmbrellaBatchHelperBase.t.sol';

contract PauseTests is UmbrellaBatchHelperTestBase {
  function test_setPauseByAdmin() external {
    assertEq(umbrellaBatchHelper.paused(), false);

    vm.startPrank(defaultAdmin);

    umbrellaBatchHelper.pause();

    assertEq(umbrellaBatchHelper.paused(), true);

    umbrellaBatchHelper.unpause();

    assertEq(umbrellaBatchHelper.paused(), false);
  }

  function test_setPauseNotByAdmin(address anyone) external {
    vm.assume(anyone != defaultAdmin);

    assertEq(umbrellaBatchHelper.paused(), false);

    vm.startPrank(anyone);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(anyone))
    );
    umbrellaBatchHelper.pause();
  }

  function test_shouldRevertWhenPauseIsActive() external {
    vm.startPrank(defaultAdmin);
    umbrellaBatchHelper.pause();

    vm.stopPrank();
    vm.startPrank(user);

    uint256 amount = 1e18;
    uint256 deadline = block.timestamp + 1e6;

    bytes32 hash = getHash(user, spender, tokenAddressesWithStata[2], amount, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.permit.selector,
      IUmbrellaBatchHelper.Permit({
        token: tokenAddressesWithStata[2],
        value: amount,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    );

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.multicall(batch);

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.permit(
      IUmbrellaBatchHelper.Permit({
        token: tokenAddressesWithStata[2],
        value: amount,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    );

    // invalid sign, but we don't care, cause we get revert earlier
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.cooldownPermit.selector,
      IUmbrellaBatchHelper.CooldownPermit({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    );

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.multicall(batch);

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.cooldownPermit(
      IUmbrellaBatchHelper.CooldownPermit({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    );

    address[] memory addresses = new address[](0);

    // invalid sign, but we don't care, cause we get revert earlier
    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.claimRewardsPermit.selector,
      IUmbrellaBatchHelper.ClaimPermit({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        rewards: addresses,
        deadline: deadline,
        v: v,
        r: r,
        s: s,
        restake: false
      })
    );

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.multicall(batch);

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.claimRewardsPermit(
      IUmbrellaBatchHelper.ClaimPermit({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        rewards: addresses,
        deadline: deadline,
        v: v,
        r: r,
        s: s,
        restake: false
      })
    );

    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.deposit.selector,
      IUmbrellaBatchHelper.IOData({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        edgeToken: address(stakeTokenWithoutStata),
        value: amount
      })
    );

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.multicall(batch);

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.deposit(
      IUmbrellaBatchHelper.IOData({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        edgeToken: address(stakeTokenWithoutStata),
        value: amount
      })
    );

    batch[0] = abi.encodeWithSelector(
      IUmbrellaBatchHelper.redeem.selector,
      IUmbrellaBatchHelper.IOData({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        edgeToken: address(stakeTokenWithoutStata),
        value: amount
      })
    );

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.multicall(batch);

    vm.expectRevert(Pausable.EnforcedPause.selector);
    umbrellaBatchHelper.redeem(
      IUmbrellaBatchHelper.IOData({
        stakeToken: IStakeToken(address(stakeTokenWithoutStata)),
        edgeToken: address(stakeTokenWithoutStata),
        value: amount
      })
    );
  }
}
