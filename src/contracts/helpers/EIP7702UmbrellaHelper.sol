// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

import {IEIP7702UmbrellaHelper} from './interfaces/IEIP7702UmbrellaHelper.sol';
import {IUniversalToken} from './interfaces/IUniversalToken.sol';

import {IERC4626StataToken} from 'aave-v3-origin/contracts/extensions/stata-token/interfaces/IERC4626StataToken.sol';

import {IStakeToken} from '../stakeToken/interfaces/IStakeToken.sol';
import {IRewardsController} from '../rewards/interfaces/IRewardsController.sol';

/**
 * @title UmbrellaBatchHelper
 * @notice UmbrellaBatchHelper is a utility contract designed to consolidate multiple transactions into a single one.
 * It simplifies deposits, withdrawals, restaking, and cooldown activation,
 * making these actions more convenient for holders of multiple `StakeToken`s.
 * @author BGD labs
 */
contract UmbrellaBatchHelper is IEIP7702UmbrellaHelper {
  using SafeERC20 for *;

  /**
   * @notice Defines possible conversion paths for a `StakeToken`.
   * @dev Used internally to determine how a token can be converted to/from a `StakeToken`.
   * @param None Indicates that the token cannot be directly converted to or from a `StakeToken`.
   * @param StataToken Indicates that deposit starts from or withdrawals ends with a `StataToken`.
   * @param AToken Indicates that deposit starts from or withdrawals ends with an `AToken`.
   * @param Token Indicates that deposit starts from or withdrawals ends with a regular `Token`.
   */
  enum Path {
    None,
    StataToken,
    AToken,
    Token
  }

  /// @inheritdoc IEIP7702UmbrellaHelper
  IRewardsController public immutable REWARDS_CONTROLLER;

  constructor(address rewardsController_) {
    require(rewardsController_ != address(0), ZeroAddress());
    REWARDS_CONTROLLER = IRewardsController(rewardsController_);
  }

  /// @inheritdoc IEIP7702UmbrellaHelper
  function deposit(IOData calldata io) external {
    (Path path, IUniversalToken underlyingOfStakeToken) = _getPath(io.stakeToken, io.edgeToken);

    require(path != Path.None, InvalidEdgeToken());

    uint256 value = io.value;

    if (path == Path.AToken) {
      // Setting `io.value` more than actual balance will deposit all balance available
      uint256 balanceInCurrentBlock = IERC20(io.edgeToken).balanceOf(address(this));

      require(balanceInCurrentBlock != 0, ZeroAmount());

      if (value > balanceInCurrentBlock) {
        value = balanceInCurrentBlock;
      }
    }
    require(value != 0, ZeroAmount());

    _depositToStake(io.stakeToken, io.edgeToken, underlyingOfStakeToken, value, path);
  }

  /// @inheritdoc IEIP7702UmbrellaHelper
  function redeem(IOData calldata io) external {
    require(io.value != 0, ZeroAmount());

    (Path path, IUniversalToken underlyingOfStakeToken) = _getPath(io.stakeToken, io.edgeToken);

    require(path != Path.None, InvalidEdgeToken());

    _redeemFromStake(io.stakeToken, underlyingOfStakeToken, io.value, path);
  }

  /**
   * @notice Deposits `edgeToken` using smart route to `StakeToken`
   * @param edgeToken Address of already transferred token
   * @param stakeTokenUnderlying Address of stake token underlying token
   * @param value Amount of `edgeToken` transferred
   * @param startPath Path to start from, can have any value (`StataToken/AToken/Token`) except `None`
   */
  function _depositToStake(
    IStakeToken stakeToken,
    address edgeToken,
    IUniversalToken stakeTokenUnderlying,
    uint256 value,
    Path startPath
  ) internal {
    // deposit to stata if needed
    if (startPath == Path.Token || startPath == Path.AToken) {
      IERC20(edgeToken).forceApprove(address(stakeTokenUnderlying), value);

      // rewrite the amount of tokens to be deposited to stake
      if (startPath == Path.Token) {
        value = stakeTokenUnderlying.deposit(value, address(this));
      } else {
        // only aToken remains here
        value = stakeTokenUnderlying.depositATokens(value, address(this));
      }
    }

    // deposit underlying asset (stata or common token) to stake
    stakeTokenUnderlying.forceApprove(address(stakeToken), value);
    stakeToken.deposit(value, address(this));
  }

  /**
   * @notice Redeems `edgeToken` using smart route from `StakeToken`
   * @param stakeTokenUnderlying Address of stake token underlying token
   * @param value Amount of `StakeToken` to be redeemed
   * @param endPath Token that ends the path, can have any value (`StataToken/AToken/Token`) except `None`
   */
  function _redeemFromStake(
    IStakeToken stakeToken,
    IUniversalToken stakeTokenUnderlying,
    uint256 value,
    Path endPath
  ) internal {
    if (endPath == Path.AToken || endPath == Path.Token) {
      // redeem stata from stake and rewrite the amount of tokens to be redeemed from stata
      value = stakeToken.redeem(value, address(this), address(this));

      if (endPath == Path.Token) {
        // redeem Token from stata
        stakeTokenUnderlying.redeem(value, address(this), address(this));
      } else {
        // only `aToken` remains here
        stakeTokenUnderlying.redeemATokens(value, address(this), address(this));
      }
    } else {
      stakeToken.redeem(value, address(this), address(this));
    }
  }

  /**
   * @notice Checks the route from edgeToken to stake token
   * @dev Reverts if it's not possible.
   * @param stakeToken Address of `StakeToken`
   * @param edgeToken Address of starting token
   */
  function _getPath(
    IStakeToken stakeToken,
    address edgeToken
  ) internal returns (Path, IUniversalToken) {
    Path path = Path.None;

    // check that `StakeToken` was initialized inside `RewardsController`
    require(
      REWARDS_CONTROLLER.getAssetData(address(stakeToken)).targetLiquidity != 0,
      NotInitializedStake()
    );

    address underlyingOfStakeToken = stakeToken.asset();

    if (underlyingOfStakeToken == edgeToken) {
      path = Path.StataToken;
    } else {
      // check if underlying token is stata or common token (like GHO or LP-token)
      (bool success, bytes memory data) = underlyingOfStakeToken.staticcall(
        abi.encodeWithSelector(IERC4626StataToken.aToken.selector)
      );

      if (success) {
        address aToken = abi.decode(data, (address));
        if (aToken == edgeToken) {
          path = Path.AToken;
        } else if (IUniversalToken(underlyingOfStakeToken).asset() == edgeToken) {
          path = Path.Token;
        }
      }
    }

    return (path, IUniversalToken(underlyingOfStakeToken));
  }
}
