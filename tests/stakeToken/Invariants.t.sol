// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {StakeTestBase} from './utils/StakeTestBase.t.sol';

contract InvariantTest is StakeTestBase {
  function test_exchangeRateAfterSlashingAlwaysIncreasing(
    uint192 amountToDeposit,
    uint192 amountToSlash
  ) external {
    amountToDeposit = uint96(
      bound(amountToDeposit, stakeToken.MIN_ASSETS_REMAINING() + 1, type(uint96).max)
    );
    amountToSlash = uint96(
      bound(amountToSlash, 1, amountToDeposit - stakeToken.MIN_ASSETS_REMAINING())
    );

    _deposit(amountToDeposit, user, user);

    uint256 defaultExchangeRate = stakeToken.previewDeposit(1);

    vm.startPrank(admin);

    stakeToken.slash(someone, amountToSlash);

    uint256 newExchangeRate = stakeToken.previewDeposit(1);

    assertLe(defaultExchangeRate, newExchangeRate);
  }

  function test_dataShouldBeNotUpdatedDuringDeposit() external {
    _deposit(1 ether, user, user);

    assertEq(mockRewardsController.lastTotalAssets(), 0);
    assertEq(mockRewardsController.lastTotalSupply(), 0);

    uint256 totalAssets = stakeToken.totalAssets();
    uint256 totalSupply = stakeToken.totalSupply();

    assertNotEq(totalAssets, 0);
    assertNotEq(totalSupply, 0);

    _deposit(1 ether, user, user);

    assertEq(mockRewardsController.lastTotalAssets(), totalAssets);
    assertEq(mockRewardsController.lastTotalSupply(), totalSupply);

    assertNotEq(totalAssets, stakeToken.totalAssets());
    assertNotEq(totalSupply, stakeToken.totalSupply());

    assertEq(mockRewardsController.lastUser(), user);
    assertEq(mockRewardsController.lastUserBalance(), stakeToken.convertToShares(1 ether));
  }

  function test_dataShouldBeNotUpdatedDuringWithdraw() external {
    _deposit(1 ether, user, user);

    uint256 newtotalAssets = stakeToken.totalAssets();
    uint256 newtotalSupply = stakeToken.totalSupply();

    vm.startPrank(user);
    stakeToken.cooldown();

    skip(stakeToken.getCooldown());

    stakeToken.withdraw(0.5 ether, user, user);

    assertEq(mockRewardsController.lastTotalAssets(), newtotalAssets);
    assertEq(mockRewardsController.lastTotalSupply(), newtotalSupply);

    assertEq(mockRewardsController.lastUser(), user);
    assertEq(mockRewardsController.lastUserBalance(), 1 ether);

    assertNotEq(newtotalAssets, stakeToken.totalAssets());
    assertNotEq(newtotalSupply, stakeToken.totalSupply());

    assertEq(mockRewardsController.lastUser(), user);
    assertEq(mockRewardsController.lastUserBalance(), stakeToken.convertToShares(1 ether));
  }

  function test_dataShouldNotBeUpdatedDuringSlash() external {
    _deposit(1 ether, user, user);

    uint256 newtotalSupply = stakeToken.totalSupply();
    uint256 newtotalAssets = stakeToken.totalAssets();

    assertEq(0, mockRewardsController.lastTotalSupply());
    assertEq(0, mockRewardsController.lastTotalAssets());

    vm.startPrank(admin);
    stakeToken.slash(someone, 0.5 ether);

    assertEq(mockRewardsController.lastTotalSupply(), newtotalSupply);
    assertEq(mockRewardsController.lastTotalAssets(), newtotalAssets);

    assertEq(address(0), mockRewardsController.lastUser());
    assertEq(0, mockRewardsController.lastUserBalance());
  }
}
