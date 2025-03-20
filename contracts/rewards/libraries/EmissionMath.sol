// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

import {InternalStructs} from './InternalStructs.sol';
import {IRewardsStructs} from '../interfaces/IRewardsStructs.sol';

/**
 * @title EmissionMath contract
 * @notice The emission math contract is designed for the calculation of the index and amount of accrued rewards related to
 * dynamic distribution based on `targetLiquidity`, current `totalAssets`, `totalSupply`, and `maxEmissionPerSecond`.
 * It consists of three segments:
 * 1) Gradual Increase: The first segment features a sharp rise in emission, providing early depositors with a better deal,
 * ultimately reaching `maxEmissionPerSecond`. The dynamics of emission growth decreases with increasing `totalAssets`.
 * 2) Linear Decrease: The second segment represents a linear decrease in emission.
 * 3) Constant Emission: The third segment maintains a constant level of emission.
 * @dev `maxEmissionPerSecond` are assumed to be scaled up to 18 decimals.
 * For example: WBTC minimal `maxEmissionPerSecond` will be 1e10, cause 1e10 is `decimalsScaling`.
 * @author BGD labs
 */
library EmissionMath {
  using SafeCast for uint256;
  using Math for uint256;

  /// @notice 100%
  uint256 internal constant PERCENTAGE_FACTOR = 100_00;

  /// @notice 120%
  uint256 internal constant FLAT_EMISSION_LIQUIDITY_BOUND = 120_00;

  /// @notice 80%
  uint256 internal constant FLAT_EMISSION_BPS = 80_00;

  /// @notice maxEmissionPerSecond should be less than 1_000 tokens, look (/assets/operating_conditions.md) for details
  uint256 internal constant MAX_EMISSION_VALUE_PER_SECOND = 1_000 * 1e18;

  /// @notice `index` and `emissionPerSecond` scaling factor
  uint256 public constant SCALING_FACTOR = 1e18;

  /// @notice Reserve in requirement for `maxEmissionPerSecond`, look (/assets/operating_conditions.md) for details
  uint256 public constant REACHABLE_RATIO = 1000;

  /// @notice Max decimals allowed for reward tokens and max recommended for asset
  uint8 public constant MAX_DECIMALS = 18;

  /// @notice DEAD_SHARES set to `totalSupply` if it's less than 1e6 value (in order to protect from overflow)
  uint256 public constant DEAD_SHARES = 1e6;

  /**
   * @dev Attempted to set `targetLiquidity` with a value less than 1 whole token considering decimals or greater than `1e36`.
   */
  error InvalidTargetLiquidity();

  /**
   * @dev Attempted to set `maxEmissionPerSecond` with a value greater than `MAX_EMISSION_VALUE_PER_SECOND`.
   */
  error InvalidMaxEmissionPerSecond();

  /**
   * @notice Calculates index increase for some period of time
   * @param extraParamsForIndex Extra params including `targetLiquidity`, `totalAssets`, `totalSupply`
   * @param maxEmissionPerSecondScaled Amount of rewards distributed every second virtually scaled up to 18 decimals
   * @param distributionEnd Timestamp when distribution should end
   * @param lastUpdateTimestamp Timestamp of last update, should be less or equal than `distributionEnd`
   * @return Index increase value
   */
  function calculateIndexIncrease(
    InternalStructs.ExtraParamsForIndex memory extraParamsForIndex,
    uint256 maxEmissionPerSecondScaled,
    uint256 distributionEnd,
    uint256 lastUpdateTimestamp
  ) internal view returns (uint144) {
    uint256 currentEmission = getEmissionPerSecondScaled(
      maxEmissionPerSecondScaled,
      extraParamsForIndex.targetLiquidity,
      extraParamsForIndex.totalAssets
    );

    uint256 calculateDistributionUntil = block.timestamp > distributionEnd
      ? distributionEnd
      : block.timestamp;

    uint256 timeDelta = calculateDistributionUntil - lastUpdateTimestamp;

    if (extraParamsForIndex.totalSupply < DEAD_SHARES) {
      extraParamsForIndex.totalSupply = DEAD_SHARES;
    }

    uint256 indexIncrease = (currentEmission * timeDelta) / extraParamsForIndex.totalSupply;

    return indexIncrease.toUint144();
  }

  /**
   * @notice Calculates virtual amount of accrued tokens for some period of time
   * @param newRewardIndex Reward index calculated, should be greater or equal than `oldUserIndex`
   * @param oldUserIndex The last user's index set during update or `handleAction`
   * @param userBalance Amount of user's `StakeToken` shares
   * @return Accrued amount of tokens virtually scaled up to 18 decimals
   */
  function calculateAccrued(
    uint152 newRewardIndex,
    uint152 oldUserIndex,
    uint256 userBalance
  ) internal pure returns (uint112) {
    return ((userBalance * (newRewardIndex - oldUserIndex)) / SCALING_FACTOR).toUint112();
  }

  /**
   * @notice Calculates all emission parameters inside `EmissionData` struct
   * @param maxEmissionPerSecond Maximum possible emission rate per second
   * @param targetLiquidity Liquidity value at which `maxEmissionPerSecond` will be applied
   * @return `EmissionData` struct
   */
  function calculateEmissionParams(
    uint256 maxEmissionPerSecond,
    uint256 targetLiquidity
  ) internal pure returns (IRewardsStructs.EmissionData memory) {
    return
      IRewardsStructs.EmissionData({
        targetLiquidity: targetLiquidity,
        targetLiquidityExcess: _percentMulDiv(targetLiquidity, FLAT_EMISSION_LIQUIDITY_BOUND),
        maxEmission: maxEmissionPerSecond,
        flatEmission: _percentMulDiv(maxEmissionPerSecond, FLAT_EMISSION_BPS)
      });
  }

  /**
   * @notice Calculate current virtual emission per second
   * @param maxEmissionPerSecondScaled Maximum possible emission rate per second virtually scaled up to 18 decimals
   * @param targetLiquidity Liquidity value at which `maxEmissionPerSecond` will be applied
   * @param totalAssets Amount of assets remaining inside `StakeToken`
   * @return Current virtual emission per second
   */
  function getEmissionPerSecondScaled(
    uint256 maxEmissionPerSecondScaled,
    uint256 targetLiquidity,
    uint256 totalAssets
  ) internal pure returns (uint256) {
    return
      _getEmissionPerSecondScaled(
        calculateEmissionParams(maxEmissionPerSecondScaled, targetLiquidity),
        totalAssets
      );
  }

  /**
   * @notice Validates `maxEmissionPerSecondScaled`
   * @param maxEmissionPerSecondScaled Maximum possible emission rate per second to validate virtually scaled up to 18 decimals
   * @param targetLiquidity Target of `totalAssets` for `StakeToken`
   */
  function validateMaxEmission(
    uint256 maxEmissionPerSecondScaled,
    uint256 targetLiquidity
  ) internal pure {
    // We want to check that minimal `maxEmissionPerSecondScaled` should be at least 2 native wei in reward
    // Considering this, for the flat sector we will get non-zero emission, cause `2 * 80% / 100%` will result in 1 wei
    uint256 precisionBound = (targetLiquidity * REACHABLE_RATIO) / SCALING_FACTOR;
    uint256 minBound = precisionBound > 2 ? precisionBound : 2;
    require(
      maxEmissionPerSecondScaled <= MAX_EMISSION_VALUE_PER_SECOND &&
        maxEmissionPerSecondScaled >= minBound,
      InvalidMaxEmissionPerSecond()
    );
  }

  /**
   * @notice Validates `targetLiquidity`
   * @param targetLiquidity Liquidity value at which `maxEmissionPerSecond` will be applied
   * @param decimals Decimals value of `asset`
   */
  function validateTargetLiquidity(uint256 targetLiquidity, uint8 decimals) internal pure {
    require(targetLiquidity >= 10 ** decimals && targetLiquidity <= 1e36, InvalidTargetLiquidity());
  }

  function _getEmissionPerSecondScaled(
    IRewardsStructs.EmissionData memory params,
    uint256 totalAssets
  ) internal pure returns (uint256) {
    if (totalAssets <= params.targetLiquidity) {
      return _slopeCurve(params.maxEmission, params.targetLiquidity, totalAssets);
    } else if (totalAssets < params.targetLiquidityExcess) {
      return _linearDecreaseCurve(params, totalAssets);
    } else {
      return params.flatEmission * SCALING_FACTOR;
    }
  }

  function _slopeCurve(
    uint256 maxEmissionPerSecond,
    uint256 targetLiquidity,
    uint256 totalAssets
  ) internal pure returns (uint256) {
    // since `totalAssets` should be always <= `targetLiquidity` here; belongs to [0; targetLiquidity]
    // `emissionDecrease` belongs to [0; maxEmissionPerSecond * SCALING_FACTOR]
    uint256 emissionDecrease = (maxEmissionPerSecond * totalAssets * SCALING_FACTOR) /
      targetLiquidity;
    // result belongs [0; maxEmissionPerSecond * SCALING_FACTOR]
    return
      ((2 * maxEmissionPerSecond * SCALING_FACTOR - emissionDecrease) * totalAssets) /
      targetLiquidity;
  }

  function _linearDecreaseCurve(
    IRewardsStructs.EmissionData memory params,
    uint256 totalAssets
  ) internal pure returns (uint256) {
    // `maxEmission` always > `flatEmission`;
    // `totalAssets` should be > `targetLiquidity` here; belongs to (targetLiquidity; targetLiquidityExcess)
    // result belongs to (flatEmission; maxEmission] or (CONST_EMISSION_BPS * maxEmission / PERCENTAGE_FACTOR; maxEmission]

    return
      (params.maxEmission -
        (((params.maxEmission - params.flatEmission) * (totalAssets - params.targetLiquidity)) /
          (params.targetLiquidityExcess - params.targetLiquidity))) * SCALING_FACTOR;
  }

  function _percentMulDiv(uint256 value, uint256 percent) internal pure returns (uint256) {
    return value.mulDiv(percent, PERCENTAGE_FACTOR);
  }

  function scaleUp(uint256 value, uint8 decimals) internal pure returns (uint256) {
    return value * 10 ** decimals;
  }

  function scaleDown(uint256 value, uint8 decimals) internal pure returns (uint256) {
    return value / (10 ** decimals);
  }
}
