// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';

import {StakeToken} from '../../src/contracts/stakeToken/StakeToken.sol';
import {IERC4626StakeToken} from '../../src/contracts/stakeToken/interfaces/IERC4626StakeToken.sol';

import {StakeTestBase} from './utils/StakeTestBase.t.sol';

contract SlashingTests is StakeTestBase {
  function test_slashNotByAdmin(address anyone) external {
    vm.assume(anyone != admin && anyone != address(proxyAdminContract));

    vm.startPrank(anyone);

    vm.expectRevert(
      abi.encodeWithSelector(
        OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
        address(anyone)
      )
    );
    stakeToken.slash(user, type(uint256).max);
  }

  function test_slash_shouldRevertWithAmountZero() public {
    vm.startPrank(admin);

    vm.expectRevert(IERC4626StakeToken.ZeroAmountSlashing.selector);
    stakeToken.slash(user, 0);
  }

  function test_slash_shouldRevertWithFundsLteMinimum(uint256 amount) public {
    amount = bound(amount, 1, stakeToken.MIN_ASSETS_REMAINING());

    _deposit(amount, user, user);

    vm.startPrank(admin);

    vm.expectRevert(IERC4626StakeToken.ZeroFundsAvailable.selector);
    stakeToken.slash(someone, type(uint256).max);
  }

  function test_slash(uint192 amountToStake, uint192 amountToSlash) public {
    amountToStake = uint192(
      bound(amountToStake, stakeToken.MIN_ASSETS_REMAINING() + 1, type(uint192).max)
    );
    amountToSlash = uint192(
      bound(amountToSlash, 1, amountToStake - stakeToken.MIN_ASSETS_REMAINING())
    );

    _deposit(amountToStake, user, user);

    vm.startPrank(admin);

    stakeToken.slash(someone, amountToSlash);

    vm.stopPrank();

    assertEq(underlying.balanceOf(someone), amountToSlash);
    assertEq(underlying.balanceOf(address(stakeToken)), amountToStake - amountToSlash);

    assertEq(stakeToken.convertToAssets(stakeToken.balanceOf(user)), amountToStake - amountToSlash);
  }

  function test_stakeAfterSlash(uint96 amountToStake, uint96 amountToSlash) public {
    amountToStake = uint96(
      bound(amountToStake, stakeToken.MIN_ASSETS_REMAINING() + 1, type(uint96).max)
    );
    amountToSlash = uint96(
      bound(amountToSlash, 1, amountToStake - stakeToken.MIN_ASSETS_REMAINING())
    );

    _deposit(amountToStake, user, user);

    vm.startPrank(admin);

    stakeToken.slash(someone, amountToSlash);

    vm.stopPrank();

    _deposit(amountToStake, user, user);

    assertEq(underlying.balanceOf(someone), amountToSlash);
    assertEq(underlying.balanceOf(address(stakeToken)), 2 * uint256(amountToStake) - amountToSlash);

    assertEq(
      stakeToken.convertToAssets(stakeToken.balanceOf(user)),
      2 * uint256(amountToStake) - amountToSlash
    );
  }
}
