// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

import {IRewardsController} from '../../src/contracts/rewards/interfaces/IRewardsController.sol';

import {StakeTestBase} from './utils/StakeTestBase.t.sol';

contract ExchangeRateTest is StakeTestBase {
  using SafeCast for uint256;

  function test_precisionLossWithSlash(uint192 assets, uint192 assetsToSlash) public {
    assets = uint192(bound(assets, stakeToken.MIN_ASSETS_REMAINING() + 1, type(uint192).max));
    assetsToSlash = uint192(bound(assetsToSlash, 1, assets - stakeToken.MIN_ASSETS_REMAINING()));

    uint256 shares = stakeToken.previewDeposit(assets);

    _deposit(assets, user, user);

    vm.startPrank(admin);

    stakeToken.slash(someone, assetsToSlash);

    vm.stopPrank();

    uint192 assetsAfterRedeem = stakeToken.previewRedeem(shares).toUint192();

    assertLe(assetsAfterRedeem, assets);

    assertLe(getDiff(assetsAfterRedeem, assets - assetsToSlash), 1);
  }

  function test_precisionLossStartingWithAssets(
    uint192 assetsToStake,
    uint192 assetsToCheck
  ) public {
    assetsToCheck = uint192(bound(assetsToCheck, 1, type(uint192).max - 1));
    assetsToStake = uint192(bound(assetsToStake, assetsToCheck + 1, type(uint192).max));

    _deposit(assetsToStake, user, user);

    uint256 sharesFromDeposit = stakeToken.previewDeposit(assetsToCheck);
    uint256 assetsFromMint = stakeToken.previewMint(sharesFromDeposit);

    assertLe(getDiff(assetsToCheck, assetsFromMint), 1);

    uint256 sharesFromWithdrawal = stakeToken.previewWithdraw(assetsToCheck);
    uint256 assetsFromRedeem = stakeToken.previewRedeem(sharesFromWithdrawal);

    assertLe(getDiff(assetsToCheck, assetsFromRedeem), 1);
  }

  function test_precisionLossStartingWithShares(
    uint192 assetsToStake,
    uint224 sharesToCheck
  ) public {
    sharesToCheck = uint192(bound(sharesToCheck, sharesMultiplier(), type(uint192).max));
    assetsToStake = uint192(
      bound(assetsToStake, stakeToken.convertToAssets(sharesToCheck), type(uint192).max)
    );

    _deposit(assetsToStake, user, user);

    uint256 assetsFromMint = stakeToken.previewMint(sharesToCheck);
    uint256 sharesFromDeposit = stakeToken.previewDeposit(assetsFromMint);

    assertLe(getDiff(sharesToCheck, sharesFromDeposit), 1000);

    uint256 assetsFromRedeem = stakeToken.previewRedeem(sharesToCheck);
    uint256 sharesFromWithdrawal = stakeToken.previewWithdraw(assetsFromRedeem);

    assertLe(getDiff(sharesToCheck, sharesFromWithdrawal), 1000);
  }

  function test_precisionLossCombinedTest(
    uint96 assets,
    uint96 assetsToSlash,
    uint96 assetsToCheck
  ) public {
    assets = uint96(bound(assets, stakeToken.MIN_ASSETS_REMAINING() + 1, type(uint96).max));
    assetsToSlash = uint96(bound(assetsToSlash, 1, assets - stakeToken.MIN_ASSETS_REMAINING()));
    assetsToCheck = uint96(bound(assetsToCheck, 1, type(uint96).max));

    stakeToken.previewDeposit(assets);

    _deposit(assets, user, user);

    vm.startPrank(admin);

    stakeToken.slash(someone, assetsToSlash);

    vm.stopPrank();

    uint256 sharesFromDeposit_1 = stakeToken.previewDeposit(assetsToCheck);
    uint256 assetsFromMint_1 = stakeToken.previewMint(sharesFromDeposit_1);

    assertEq(assetsToCheck - assetsFromMint_1, 0);

    uint256 sharesFromWithdrawal_1 = stakeToken.previewWithdraw(assetsToCheck);
    uint256 assetsFromRedeem_1 = stakeToken.previewRedeem(sharesFromWithdrawal_1);

    assertEq(assetsToCheck - assetsFromRedeem_1, 0);

    // check, cause they have different rounding, but same convertToShares with the same assets started
    assertLe(getDiff(sharesFromDeposit_1, sharesFromWithdrawal_1), 1);
  }
}
