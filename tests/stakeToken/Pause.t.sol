// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {PausableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol';
import {ERC4626Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol';

import {StakeTestBase} from './utils/StakeTestBase.t.sol';

contract PauseTests is StakeTestBase {
  function test_setPauseByAdmin() external {
    assertEq(PausableUpgradeable(address(stakeToken)).paused(), false);

    vm.startPrank(admin);

    stakeToken.pause();

    assertEq(PausableUpgradeable(address(stakeToken)).paused(), true);

    stakeToken.unpause();

    assertEq(PausableUpgradeable(address(stakeToken)).paused(), false);
  }

  function test_setPauseNotByAdmin(address anyone) external {
    vm.assume(anyone != admin && anyone != address(proxyAdminContract));

    assertEq(PausableUpgradeable(address(stakeToken)).paused(), false);

    vm.startPrank(anyone);

    vm.expectRevert(
      abi.encodeWithSelector(
        OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
        address(anyone)
      )
    );
    stakeToken.pause();
  }

  function test_shouldRevertWhenPauseIsActive() external {
    _deposit(1e18, user, user);
    _dealUnderlying(1e18, user);

    vm.startPrank(user);

    stakeToken.cooldown();
    stakeToken.approve(someone, 1000);
    stakeToken.setCooldownOperator(someone, true);
    underlying.approve(address(stakeToken), 1e18);

    skip(stakeToken.getCooldown());

    assertNotEq(stakeToken.maxDeposit(user), 0);
    assertNotEq(stakeToken.maxMint(user), 0);
    assertNotEq(stakeToken.maxWithdraw(user), 0);
    assertNotEq(stakeToken.maxRedeem(user), 0);
    assertNotEq(stakeToken.getMaxSlashableAssets(), 0);

    vm.stopPrank();
    vm.startPrank(admin);

    stakeToken.pause();

    vm.stopPrank();
    vm.startPrank(someone);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    stakeToken.cooldownOnBehalfOf(user);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    stakeToken.transferFrom(user, someone, 1);

    vm.stopPrank();
    vm.startPrank(user);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    stakeToken.cooldown();

    // error is another one, due to zero-liq checks before pause check
    vm.expectRevert(
      abi.encodeWithSelector(ERC4626Upgradeable.ERC4626ExceededMaxDeposit.selector, user, 1, 0)
    );
    stakeToken.deposit(1, user);

    vm.expectRevert(
      abi.encodeWithSelector(ERC4626Upgradeable.ERC4626ExceededMaxMint.selector, user, 1, 0)
    );
    stakeToken.mint(1, user);

    vm.expectRevert(
      abi.encodeWithSelector(ERC4626Upgradeable.ERC4626ExceededMaxRedeem.selector, user, 1, 0)
    );
    stakeToken.redeem(1, user, user);

    vm.expectRevert(
      abi.encodeWithSelector(ERC4626Upgradeable.ERC4626ExceededMaxWithdraw.selector, user, 1, 0)
    );
    stakeToken.withdraw(1, user, user);

    assertEq(stakeToken.maxDeposit(user), 0);
    assertEq(stakeToken.maxMint(user), 0);
    assertEq(stakeToken.maxWithdraw(user), 0);
    assertEq(stakeToken.maxRedeem(user), 0);
    assertEq(stakeToken.getMaxSlashableAssets(), 0);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    stakeToken.transfer(someone, 1);

    vm.stopPrank();
    vm.startPrank(admin);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    stakeToken.slash(someone, 1);
  }
}
