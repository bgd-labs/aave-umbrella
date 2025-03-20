// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

import {Pausable} from 'openzeppelin-contracts/contracts/utils/Pausable.sol';
import {Multicall} from 'openzeppelin-contracts/contracts/utils/Multicall.sol';

import {IRescuableBase, RescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';

import {IUmbrellaBatchHelper} from './interfaces/IUmbrellaBatchHelper.sol';
import {IUniversalToken} from './interfaces/IUniversalToken.sol';

import {IStataTokenV2} from 'aave-v3-origin/contracts/extensions/stata-token/interfaces/IStataTokenV2.sol';
import {IERC4626StataToken} from 'aave-v3-origin/contracts/extensions/stata-token/interfaces/IERC4626StataToken.sol';

import {IStakeToken} from '../stakeToken/interfaces/IStakeToken.sol';
import {IERC4626StakeToken} from '../stakeToken/interfaces/IERC4626StakeToken.sol';

import {IRewardsController} from '../rewards/interfaces/IRewardsController.sol';
import {IRewardsStructs} from '../rewards/interfaces/IRewardsStructs.sol';

/**
 * @title UmbrellaBatchHelper
 * @notice UmbrellaBatchHelper is a utility contract designed to consolidate multiple transactions into a single one.
 * It simplifies deposits, withdrawals, restaking, and cooldown activation,
 * making these actions more convenient for holders of multiple `StakeToken`s.
 * @author BGD labs
 */
contract UmbrellaBatchHelper is IUmbrellaBatchHelper, Ownable, Pausable, Multicall, Rescuable {
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

  struct Info {
    /// @notice Set to true, when path is initialized for `StakeToken`
    bool initialized;
    /// @notice Set to true, when underlying token of stake is stata
    bool isStata;
    /// @notice Address of the underlying token from stake
    IUniversalToken stakeTokenUnderlying;
  }

  struct Config {
    /// @notice 1-slot info
    Info info;
    /// @notice Mapping to get start/end path from `transactionToken` or `reward`
    mapping(address => Path) tokenToPath;
  }

  /// @notice Internal mapping with `StakeToken` path configs
  mapping(IStakeToken => Config) internal _configs;

  /// @inheritdoc IUmbrellaBatchHelper
  IRewardsController public immutable REWARDS_CONTROLLER;

  constructor(address rewardsController_, address owner_) Ownable(owner_) {
    require(rewardsController_ != address(0), ZeroAddress());

    REWARDS_CONTROLLER = IRewardsController(rewardsController_);
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function initializePath(IStakeToken[] calldata stakeTokens) external {
    for (uint256 i; i < stakeTokens.length; ++i) {
      _checkAndInitializePath(stakeTokens[i]);
    }
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function cooldownPermit(CooldownPermit calldata p) external whenNotPaused {
    _checkAndInitializePath(p.stakeToken);
    // Due to the fact, that `StakeToken` uses `_msgSender()` inside digest, then signature shouldn't be able
    // to be reused by external actor, that's why there's no try-catch here
    p.stakeToken.cooldownWithPermit(
      _msgSender(),
      p.deadline,
      IERC4626StakeToken.SignatureParams(p.v, p.r, p.s)
    );
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function claimRewardsPermit(ClaimPermit calldata p) external whenNotPaused {
    _checkAndInitializePath(p.stakeToken);

    uint256[] memory amounts = _claimRewardsPermit(p);

    // If restake is set to true, then rewards are transferred to this contract, otherwise to `_msgSender()`
    if (!p.restake) {
      return;
    }

    Config storage config = _configs[p.stakeToken];

    // `amounts` length is always the same as `p.rewards` length
    for (uint256 i; i < amounts.length; ++i) {
      if (amounts[i] == 0) {
        continue;
      }

      Path startPath = config.tokenToPath[p.rewards[i]];

      // If `reward` is `aToken` or another token with dynamic balance, then transfer could lead to some wei loss
      uint256 actualAmountReceived = IERC20(p.rewards[i]).balanceOf(address(this));

      if (actualAmountReceived == 0) {
        continue;
      }

      if (actualAmountReceived < amounts[i]) {
        amounts[i] = actualAmountReceived;
      }

      if (startPath == Path.None) {
        // Can't restake this token, so just transfer to `_msgSender()`
        IERC20(p.rewards[i]).safeTransfer(_msgSender(), amounts[i]);
      } else {
        // Restake token
        _depositToStake(p.stakeToken, p.rewards[i], amounts[i], config.info, startPath);
      }
    }
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function permit(Permit calldata p) external whenNotPaused {
    // To prevent a griefing attack where a malicious actor duplicates the `permit` call (with the same signature and params)
    // directly to the token we wrap it into a `try-catch` block
    try
      IERC20Permit(p.token).permit(_msgSender(), address(this), p.value, p.deadline, p.v, p.r, p.s)
    {} catch {}
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function deposit(IOData calldata io) external whenNotPaused {
    require(io.value != 0, ZeroAmount());

    _checkAndInitializePath(io.stakeToken);

    Config storage config = _configs[io.stakeToken];

    Path path = config.tokenToPath[io.edgeToken];
    require(path != Path.None, InvalidEdgeToken());

    uint256 value = io.value;

    if (path == Path.AToken) {
      bool wholeBalanceTransferred;
      // If we are using `aToken`s, then we can't guarantee that whole balance will be sent to the helper, cause of it's dynamic growth
      // So, setting `io.value` more than actual balance will transfer all balance available
      uint256 balanceInCurrentBlock = IERC20(io.edgeToken).balanceOf(_msgSender());

      require(balanceInCurrentBlock != 0, ZeroAmount());

      if (value > balanceInCurrentBlock) {
        wholeBalanceTransferred = true;
        value = balanceInCurrentBlock;
      }

      IERC20(io.edgeToken).safeTransferFrom(_msgSender(), address(this), value);

      // `aToken` transfer could lead to some wei being lost if not whole balance has been transferred
      if (!wholeBalanceTransferred) {
        uint256 actualAmountReceived = IERC20(io.edgeToken).balanceOf(address(this));

        if (value > actualAmountReceived) {
          value = actualAmountReceived;
        }
      }
    } else {
      // Transfer `StataToken` and `Token` without dynamic balance growth
      IERC20(io.edgeToken).safeTransferFrom(_msgSender(), address(this), value);
    }

    _depositToStake(io.stakeToken, io.edgeToken, value, config.info, path);
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function redeem(IOData calldata io) external whenNotPaused {
    require(io.value != 0, ZeroAmount());

    _checkAndInitializePath(io.stakeToken);

    Config storage config = _configs[io.stakeToken];

    Path path = config.tokenToPath[io.edgeToken];
    require(path != Path.None, InvalidEdgeToken());

    _redeemFromStake(io.stakeToken, io.value, config.info, path);
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function pause() external onlyOwner {
    _pause();
  }

  /// @inheritdoc IUmbrellaBatchHelper
  function unpause() external onlyOwner {
    _unpause();
  }

  function whoCanRescue() public view override returns (address) {
    return owner();
  }

  function maxRescue(
    address
  ) public pure override(IRescuableBase, RescuableBase) returns (uint256) {
    return type(uint256).max;
  }

  /**
   * @notice Claims rewards on behalf of `_msgSender`.
   * @dev Rewards could be transferred to this balance (if `restake` flag is `true`) or to the `_msgSender`
   * @param p Struct with all necessary data
   */
  function _claimRewardsPermit(ClaimPermit calldata p) internal returns (uint256[] memory) {
    // Due to the fact, that `RewardsController` uses `msg.sender` inside digest, then signature shouldn't
    // be able to be reused by external actor, that's why there's no try-catch here
    return
      REWARDS_CONTROLLER.claimSelectedRewardsPermit(
        address(p.stakeToken),
        p.rewards,
        _msgSender(),
        p.restake ? address(this) : _msgSender(),
        p.deadline,
        IRewardsStructs.SignatureParams(p.v, p.r, p.s)
      );
  }

  /**
   * @notice Deposits `edgeToken` using smart route to `StakeToken`
   * @param edgeToken Address of already transferred token
   * @param value Amount of `edgeToken` transferred
   * @param info Struct with common information about `StakeToken`
   * @param startPath Path to start from, can have any value (`StataToken/AToken/Token`) except `None`
   */
  function _depositToStake(
    IStakeToken stakeToken,
    address edgeToken,
    uint256 value,
    Info memory info,
    Path startPath
  ) internal {
    // deposit to stata if needed
    if (_needToUseStata(startPath, info.isStata)) {
      IERC20(edgeToken).forceApprove(address(info.stakeTokenUnderlying), value);

      // rewrite the amount of tokens to be deposited to stake
      if (startPath == Path.Token) {
        value = info.stakeTokenUnderlying.deposit(value, address(this));
      } else {
        // only aToken remains here
        value = info.stakeTokenUnderlying.depositATokens(value, address(this));
      }
    }

    // deposit underlying asset (stata or common token) to stake
    info.stakeTokenUnderlying.forceApprove(address(stakeToken), value);
    stakeToken.deposit(value, _msgSender());
  }

  /**
   * @notice Redeems `edgeToken` using smart route from `StakeToken`
   * @param value Amount of `StakeToken` to be redeemed
   * @param info Struct with common information about `StakeToken`
   * @param endPath Token that ends the path, can have any value (`StataToken/AToken/Token`) except `None`
   */
  function _redeemFromStake(
    IStakeToken stakeToken,
    uint256 value,
    Info memory info,
    Path endPath
  ) internal {
    if (_needToUseStata(endPath, info.isStata)) {
      // redeem stata from stake and rewrite the amount of tokens to be redeemed from stata
      value = stakeToken.redeem(value, address(this), _msgSender());

      if (endPath == Path.Token) {
        // redeem Token from stata
        info.stakeTokenUnderlying.redeem(value, _msgSender(), address(this));
      } else {
        // only `aToken` remains here
        info.stakeTokenUnderlying.redeemATokens(value, _msgSender(), address(this));
      }
    } else {
      stakeToken.redeem(value, _msgSender(), _msgSender());
    }
  }

  /**
   * @notice Checks that smart route is initialized. Initializes if it's possible and hasn't been made before.
   * @dev Reverts if it's not possible.
   * @param stakeToken Address of `StakeToken`
   */
  function _checkAndInitializePath(IStakeToken stakeToken) internal {
    if (!_configs[stakeToken].info.initialized) {
      // check that `StakeToken` was initialized inside `RewardsController`
      require(
        REWARDS_CONTROLLER.getAssetData(address(stakeToken)).targetLiquidity != 0,
        NotInitializedStake()
      );

      Config storage config = _configs[stakeToken];
      address underlyingOfStakeToken = stakeToken.asset();
      address token;

      // check if underlying token is stata or common token (like GHO or LP-token)
      (bool success, bytes memory data) = address(underlyingOfStakeToken).staticcall(
        abi.encodeWithSelector(IERC4626StataToken.aToken.selector)
      );

      if (success) {
        address aToken = abi.decode(data, (address));

        config.tokenToPath[underlyingOfStakeToken] = Path.StataToken;
        config.tokenToPath[aToken] = Path.AToken;

        // Asset of `StataToken` is `Token` itself, not `aToken`
        token = IUniversalToken(underlyingOfStakeToken).asset();
      } else {
        token = underlyingOfStakeToken;
      }

      config.tokenToPath[token] = Path.Token;

      config.info = Info({
        initialized: true,
        isStata: underlyingOfStakeToken != token,
        stakeTokenUnderlying: IUniversalToken(underlyingOfStakeToken)
      });

      emit AssetPathInitialized(address(stakeToken));
    }
  }

  /**
   * @notice Checks if `deposit/withdrawal` to/from `StataToken` is needed or not.
   * @param path Path to start from / end with
   * @param isStata Flag, true is underlying of `StakeToken` is `StataToken`, false otherwise
   */
  function _needToUseStata(Path path, bool isStata) internal pure returns (bool) {
    // If `isStata == false`, then path could be only `Token` -> always return `false`
    // If `isStata == true`, then path could be `Token`, `AToken` and `StataToken` -> return `false` if `path` is `StataToken`, `true` otherwise
    return path != Path.StataToken && isStata;
  }
}
