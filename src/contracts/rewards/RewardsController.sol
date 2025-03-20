// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Initializable} from 'openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol';
import {AccessControlUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol';

import {IERC4626} from 'openzeppelin-contracts/contracts/interfaces/IERC4626.sol';
import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

import {IRescuableBase} from 'solidity-utils/contracts/utils/interfaces/IRescuableBase.sol';
import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {RescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {RescuableACL} from 'solidity-utils/contracts/utils/RescuableACL.sol';

import {IRewardsDistributor} from './interfaces/IRewardsDistributor.sol';
import {IRewardsController} from './interfaces/IRewardsController.sol';

import {InternalStructs} from './libraries/InternalStructs.sol';
import {EmissionMath} from './libraries/EmissionMath.sol';

import {RewardsDistributor} from './RewardsDistributor.sol';

/**
 * @title RewardsController
 * @notice RewardsController is a contract that is intended for configuring assets,
 * the corresponding rewards for them, as well as updating data related to the distribution of rewards.
 * Calculation of rewards emission will be carried out by the `EmissionMath` library.
 * @author BGD labs
 */
contract RewardsController is
  Initializable,
  RewardsDistributor,
  AccessControlUpgradeable,
  RescuableACL,
  IRewardsController
{
  using SafeERC20 for IERC20Metadata;
  using SafeCast for uint256;
  using EmissionMath for *;

  /// @custom:storage-location erc7201:umbrella.storage.RewardsController
  struct RewardsControllerStorage {
    /// @notice Map of asset addresses and their data
    mapping(address asset => InternalStructs.AssetData) assetsData;
    // Array of all initialized assets
    address[] assets;
  }

  // keccak256(abi.encode(uint256(keccak256("umbrella.storage.RewardsController")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant RewardsControllerStorageLocation =
    0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300;

  function _getRewardsControllerStorage()
    private
    pure
    returns (RewardsControllerStorage storage $)
  {
    assembly {
      $.slot := RewardsControllerStorageLocation
    }
  }

  uint256 public constant MAX_REWARDS_LENGTH = 8;

  bytes32 public constant REWARDS_ADMIN_ROLE = keccak256('REWARDS_ADMIN_ROLE');

  constructor() {
    _disableInitializers();
  }

  function initialize(address governance) external initializer {
    require(governance != address(0), ZeroAddress());

    __AccessControl_init();
    __RewardsDistributor_init();

    _grantRole(DEFAULT_ADMIN_ROLE, governance);
    _grantRole(REWARDS_ADMIN_ROLE, governance);
  }

  /// @inheritdoc IRewardsController
  function configureAssetWithRewards(
    address asset,
    uint256 targetLiquidity,
    RewardSetupConfig[] calldata newRewardConfigs
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    _configureAsset(assetData, asset, targetLiquidity);

    for (uint256 i; i < newRewardConfigs.length; ++i) {
      _setUpReward(assetData, newRewardConfigs[i], asset);
    }

    // Due to the fact that we have a dependency between `maxEmissionPerSecond` and `targetLiquidity`,
    // we need to validate that rewards with unchanged `maxEmissionPerSecond` meet our requirements by changing `targetLiquidity`
    _validateOtherRewardEmissions(assetData, targetLiquidity);
  }

  /// @inheritdoc IRewardsDistributor
  function setClaimer(
    address user,
    address claimer,
    bool flag
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    require(user != address(0), ZeroAddress());

    _setClaimer(user, claimer, flag);
  }

  /// @inheritdoc IRewardsController
  function configureRewards(
    address asset,
    RewardSetupConfig[] calldata newRewardConfigs
  ) external onlyRole(REWARDS_ADMIN_ROLE) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    _updateData(
      assetData,
      _getExtraParamsForIndex(assetData.targetLiquidity, asset),
      asset,
      address(0),
      0
    );

    for (uint256 i; i < newRewardConfigs.length; ++i) {
      require(
        _isRewardInitialized(assetData.data[newRewardConfigs[i].reward].rewardData),
        RewardNotInitialized(newRewardConfigs[i].reward)
      );

      _configureReward(assetData, newRewardConfigs[i], asset);
    }
  }

  /// @inheritdoc IRewardsController
  function handleAction(
    uint256 totalSupply,
    uint256 totalAssets,
    address user,
    uint256 userBalance
  ) external {
    address asset = _msgSender();

    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    _updateData(
      assetData,
      InternalStructs.ExtraParamsForIndex({
        targetLiquidity: assetData.targetLiquidity,
        totalAssets: totalAssets,
        totalSupply: totalSupply
      }),
      asset,
      user,
      userBalance
    );
  }

  /// @inheritdoc IRewardsController
  function updateAsset(address asset) external {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    InternalStructs.ExtraParamsForIndex memory extraParams = _getExtraParamsForIndex(
      assetData.targetLiquidity,
      asset
    );

    if (extraParams.totalSupply != 0) {
      _updateData(assetData, extraParams, asset, address(0), 0);
    }
  }

  /// @inheritdoc IRewardsController
  function getAllAssets() external view returns (address[] memory) {
    RewardsControllerStorage storage $ = _getRewardsControllerStorage();
    address[] memory assets = new address[]($.assets.length);

    for (uint256 i; i < assets.length; ++i) {
      assets[i] = $.assets[i];
    }

    return assets;
  }

  /// @inheritdoc IRewardsController
  function getAssetAndRewardsData(
    address asset
  ) external view returns (AssetDataExternal memory, RewardDataExternal[] memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    AssetDataExternal memory assetDataExternal = getAssetData(asset);
    RewardDataExternal[] memory rewardsDataExternal = new RewardDataExternal[](
      assetData.rewardsInfo.length
    );

    for (uint256 i; i < rewardsDataExternal.length; ++i) {
      rewardsDataExternal[i] = getRewardData(asset, assetData.rewardsInfo[i].addr);
    }

    return (assetDataExternal, rewardsDataExternal);
  }

  /// @inheritdoc IRewardsController
  function getEmissionData(
    address asset,
    address reward
  ) external view returns (EmissionData memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    InternalStructs.RewardData memory rewardData = assetData.data[reward].rewardData;
    uint256 maxEmissionPerSecond = block.timestamp < rewardData.distributionEnd
      ? rewardData.maxEmissionPerSecondScaled.scaleDown(rewardData.decimalsScaling)
      : 0;

    return EmissionMath.calculateEmissionParams(maxEmissionPerSecond, assetData.targetLiquidity);
  }

  /// @inheritdoc IRewardsController
  function calculateCurrentEmissionScaled(
    address asset,
    address reward
  ) external view returns (uint256) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    InternalStructs.RewardData memory rewardData = assetData.data[reward].rewardData;

    if (block.timestamp > rewardData.distributionEnd) {
      return 0;
    }

    return
      EmissionMath.getEmissionPerSecondScaled(
        rewardData.maxEmissionPerSecondScaled,
        assetData.targetLiquidity,
        IERC4626(asset).totalAssets()
      ) / EmissionMath.SCALING_FACTOR;
  }

  /// @inheritdoc IRewardsController
  function calculateCurrentEmission(address asset, address reward) external view returns (uint256) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    InternalStructs.RewardData memory rewardData = assetData.data[reward].rewardData;

    if (block.timestamp > rewardData.distributionEnd) {
      return 0;
    }

    return
      EmissionMath.getEmissionPerSecondScaled(
        rewardData.maxEmissionPerSecondScaled,
        assetData.targetLiquidity,
        IERC4626(asset).totalAssets()
      ) / (EmissionMath.SCALING_FACTOR.scaleUp(rewardData.decimalsScaling));
  }

  /// @inheritdoc IRewardsController
  function calculateRewardIndexes(
    address asset
  ) external view returns (address[] memory, uint256[] memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    address[] memory rewards = new address[](assetData.rewardsInfo.length);
    uint256[] memory rewardsIndexes = new uint256[](rewards.length);

    for (uint256 i; i < rewards.length; ++i) {
      rewards[i] = assetData.rewardsInfo[i].addr;
      rewardsIndexes[i] = calculateRewardIndex(asset, rewards[i]);
    }

    return (rewards, rewardsIndexes);
  }

  /// @inheritdoc IRewardsController
  function getUserDataByAsset(
    address asset,
    address user
  ) external view returns (address[] memory, UserDataExternal[] memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    address[] memory rewards = new address[](assetData.rewardsInfo.length);
    UserDataExternal[] memory userData = new UserDataExternal[](rewards.length);
    InternalStructs.UserData memory userDataCache;

    for (uint256 i; i < rewards.length; ++i) {
      rewards[i] = assetData.rewardsInfo[i].addr;

      InternalStructs.RewardAndUserData storage rewardAndUserData = assetData.data[rewards[i]];
      userDataCache = rewardAndUserData.userData[user];

      userData[i] = UserDataExternal({
        index: userDataCache.index,
        accrued: userDataCache.accrued.scaleDown(rewardAndUserData.rewardData.decimalsScaling)
      });
    }

    return (rewards, userData);
  }

  /// @inheritdoc IRewardsController
  function getUserDataByReward(
    address asset,
    address reward,
    address user
  ) external view returns (UserDataExternal memory) {
    InternalStructs.RewardAndUserData storage data = _getRewardsControllerStorage()
      .assetsData[asset]
      .data[reward];
    InternalStructs.UserData memory userDataCache = data.userData[user];

    return
      UserDataExternal({
        index: userDataCache.index,
        accrued: userDataCache.accrued.scaleDown(data.rewardData.decimalsScaling)
      });
  }

  /// @inheritdoc IRewardsController
  function calculateCurrentUserRewards(
    address asset,
    address user
  ) external view returns (address[] memory, uint256[] memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    address[] memory rewards = new address[](assetData.rewardsInfo.length);
    uint256[] memory accruedAmounts = new uint256[](rewards.length);

    for (uint256 i; i < rewards.length; ++i) {
      rewards[i] = assetData.rewardsInfo[i].addr;
      accruedAmounts[i] = calculateCurrentUserReward(asset, rewards[i], user);
    }

    return (rewards, accruedAmounts);
  }

  /// @inheritdoc IRewardsController
  function getAllRewards(
    address asset
  ) public view override(IRewardsController, RewardsDistributor) returns (address[] memory) {
    InternalStructs.RewardAddrAndDistrEnd[] storage rewardsInfo = _getRewardsControllerStorage()
      .assetsData[asset]
      .rewardsInfo;

    address[] memory rewards = new address[](rewardsInfo.length);

    for (uint256 i; i < rewards.length; ++i) {
      rewards[i] = rewardsInfo[i].addr;
    }

    return rewards;
  }

  /// @inheritdoc IRewardsController
  function getAssetData(address asset) public view returns (AssetDataExternal memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    return
      AssetDataExternal({
        targetLiquidity: assetData.targetLiquidity,
        lastUpdateTimestamp: assetData.lastUpdateTimestamp
      });
  }

  /// @inheritdoc IRewardsController
  function getRewardData(
    address asset,
    address reward
  ) public view returns (RewardDataExternal memory) {
    InternalStructs.RewardData memory rewardData = _getRewardsControllerStorage()
      .assetsData[asset]
      .data[reward]
      .rewardData;
    uint256 maxEmissionPerSecond = block.timestamp < rewardData.distributionEnd
      ? rewardData.maxEmissionPerSecondScaled.scaleDown(rewardData.decimalsScaling)
      : 0;

    return
      RewardDataExternal({
        addr: reward,
        index: rewardData.index,
        maxEmissionPerSecond: maxEmissionPerSecond,
        distributionEnd: rewardData.distributionEnd
      });
  }

  /// @inheritdoc IRewardsController
  function calculateRewardIndex(address asset, address reward) public view returns (uint256) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];

    InternalStructs.RewardData memory rewardData = assetData.data[reward].rewardData;
    uint32 lastUpdateTimestamp = assetData.lastUpdateTimestamp;

    if (lastUpdateTimestamp >= rewardData.distributionEnd) {
      return rewardData.index;
    }

    return
      rewardData.index +
      EmissionMath.calculateIndexIncrease(
        _getExtraParamsForIndex(assetData.targetLiquidity, asset),
        rewardData.maxEmissionPerSecondScaled,
        rewardData.distributionEnd,
        lastUpdateTimestamp
      );
  }

  /// @inheritdoc IRewardsController
  function calculateCurrentUserReward(
    address asset,
    address reward,
    address user
  ) public view returns (uint256) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    InternalStructs.RewardAndUserData storage rewardAndUserData = assetData.data[reward];

    InternalStructs.RewardData memory rewardData = rewardAndUserData.rewardData;
    InternalStructs.UserData memory userData = rewardAndUserData.userData[user];

    uint32 lastUpdateTimestamp = assetData.lastUpdateTimestamp;
    uint256 userBalance = IERC4626(asset).balanceOf(user);

    if (lastUpdateTimestamp < rewardData.distributionEnd) {
      rewardData.index += EmissionMath.calculateIndexIncrease(
        _getExtraParamsForIndex(assetData.targetLiquidity, asset),
        rewardData.maxEmissionPerSecondScaled,
        rewardData.distributionEnd,
        lastUpdateTimestamp
      );
    }

    return
      (userData.accrued +
        EmissionMath.calculateAccrued(rewardData.index, userData.index, userBalance)).scaleDown(
          rewardData.decimalsScaling
        );
  }

  function maxRescue(
    address
  ) public pure override(IRescuableBase, RescuableBase) returns (uint256) {
    return type(uint256).max;
  }

  function _configureAsset(
    InternalStructs.AssetData storage assetData,
    address asset,
    uint256 targetLiquidity
  ) internal {
    if (_isAssetInitialized(assetData)) {
      // We need to update data, cause asset was previously initialized and `targetLiquidity` may change during this tx,
      // so we need to recalculate all existing reward indexes
      _updateData(
        assetData,
        _getExtraParamsForIndex(assetData.targetLiquidity, asset),
        asset,
        address(0),
        0
      );
    } else {
      // otherwise we need to initialize asset
      _getRewardsControllerStorage().assets.push(asset);

      emit AssetInitialized(asset);

      _updateTimestamp(assetData, asset);
    }

    _updateTarget(assetData, asset, targetLiquidity);
  }

  function _setUpReward(
    InternalStructs.AssetData storage assetData,
    RewardSetupConfig memory newConfig,
    address asset
  ) internal {
    require(newConfig.reward != address(0), ZeroAddress());

    if (_isRewardInitialized(assetData.data[newConfig.reward].rewardData)) {
      _configureReward(assetData, newConfig, asset);
    } else {
      _initializeReward(assetData, newConfig, asset);
    }
  }

  function _initializeReward(
    InternalStructs.AssetData storage assetData,
    RewardSetupConfig memory newConfig,
    address asset
  ) internal {
    require(assetData.rewardsInfo.length < MAX_REWARDS_LENGTH, MaxRewardsLengthReached());

    uint8 decimalsScaling = EmissionMath.MAX_DECIMALS - IERC20Metadata(newConfig.reward).decimals();
    uint256 maxEmissionPerSecondScaled = newConfig.maxEmissionPerSecond.scaleUp(decimalsScaling);

    EmissionMath.validateMaxEmission(maxEmissionPerSecondScaled, assetData.targetLiquidity);

    // We can't initialize reward with disabled distribution.
    require(newConfig.distributionEnd > block.timestamp, InvalidDistributionEnd());

    assetData.rewardsInfo.push(
      InternalStructs.RewardAddrAndDistrEnd(newConfig.reward, newConfig.distributionEnd.toUint32())
    );

    // `decimalsScaling` set only once during initialization
    InternalStructs.RewardAndUserData storage rewardAndUserData = assetData.data[newConfig.reward];
    rewardAndUserData.rewardData.decimalsScaling = decimalsScaling;

    emit RewardInitialized(asset, newConfig.reward);

    _updateRewardConfig(rewardAndUserData, newConfig, asset);
  }

  function _configureReward(
    InternalStructs.AssetData storage assetData,
    RewardSetupConfig memory newConfig,
    address asset
  ) internal {
    InternalStructs.RewardAndUserData storage rewardAndUserData = assetData.data[newConfig.reward];
    InternalStructs.RewardData memory rewardData = rewardAndUserData.rewardData;
    uint256 maxEmissionPerSecondScaled;

    if (newConfig.distributionEnd <= block.timestamp || newConfig.maxEmissionPerSecond == 0) {
      // if reward should be disabled, then we need to set `maxEmissionPerSecond` to zero and `distributionEnd` to block.timestamp
      newConfig.distributionEnd = block.timestamp;
      newConfig.maxEmissionPerSecond = 0;
    } else {
      // otherwise we need to validate `maxEmissionPerSecond` parameter
      maxEmissionPerSecondScaled = newConfig.maxEmissionPerSecond.scaleUp(
        rewardData.decimalsScaling
      );
      EmissionMath.validateMaxEmission(maxEmissionPerSecondScaled, assetData.targetLiquidity);
    }

    if (rewardData.distributionEnd != newConfig.distributionEnd) {
      _updateDistributionEndInRewardsInfo(assetData, newConfig.reward, newConfig.distributionEnd);
    }

    _updateRewardConfig(rewardAndUserData, newConfig, asset);
  }

  function _updateTarget(
    InternalStructs.AssetData storage assetData,
    address asset,
    uint256 newTargetLiquidity
  ) internal {
    EmissionMath.validateTargetLiquidity(newTargetLiquidity, IERC20Metadata(asset).decimals());

    assetData.targetLiquidity = newTargetLiquidity.toUint160();

    emit TargetLiquidityUpdated(asset, newTargetLiquidity);
  }

  function _updateTimestamp(InternalStructs.AssetData storage assetData, address asset) internal {
    assetData.lastUpdateTimestamp = (block.timestamp).toUint32();

    emit LastTimestampUpdated(asset, block.timestamp);
  }

  function _updateRewardConfig(
    InternalStructs.RewardAndUserData storage rewardAndUserData,
    RewardSetupConfig memory newConfig,
    address asset
  ) internal {
    require(newConfig.rewardPayer != address(0), ZeroAddress());

    InternalStructs.RewardData memory rewardData = rewardAndUserData.rewardData;

    // if `newConfig.maxEmissionPerSecond == 0`, then zero will be set
    // otherwise already validated value will be set
    rewardData.maxEmissionPerSecondScaled = (
      newConfig.maxEmissionPerSecond.scaleUp(rewardData.decimalsScaling)
    ).toUint72();

    // `distributionEnd >= block.timestamp` already validated before
    rewardData.distributionEnd = newConfig.distributionEnd.toUint32();

    // `index` and `decimalsScaling` shouldn't change during this action
    rewardAndUserData.rewardData = rewardData;
    rewardAndUserData.rewardPayer = newConfig.rewardPayer;

    emit RewardConfigUpdated(
      asset,
      newConfig.reward,
      newConfig.maxEmissionPerSecond,
      newConfig.distributionEnd,
      newConfig.rewardPayer
    );
  }

  function _updateDistributionEndInRewardsInfo(
    InternalStructs.AssetData storage assetData,
    address reward,
    uint256 distributionEnd
  ) internal {
    uint256 rewardsLength = assetData.rewardsInfo.length;

    for (uint256 i; i < rewardsLength; ++i) {
      if (assetData.rewardsInfo[i].addr == reward) {
        assetData.rewardsInfo[i].distributionEnd = distributionEnd.toUint32();

        break;
      }
    }
  }

  function _updateData(
    InternalStructs.AssetData storage assetData,
    InternalStructs.ExtraParamsForIndex memory extraParamsForIndexScaled,
    address asset,
    address user,
    uint256 userBalance
  ) internal {
    // instead of `isAssetInitialized(assetData)` we can place here this check, cause `extraParamsForIndexScaled.targetLiquidity` is get from `assetData.targetLiquidity`
    require(extraParamsForIndexScaled.targetLiquidity != 0, AssetNotInitialized(asset));

    uint32 lastUpdateTimestamp = assetData.lastUpdateTimestamp;
    uint256 rewardsLength = assetData.rewardsInfo.length;

    // we will cache pointer to `RewardAndUserData` struct in storage and reuse it inside `updateRewardIndex` and `updateUserData` functions
    // because recalculating the `_getRewardsControllerStorage().assetsData[asset].data[reward]` for pointer requires ~200 gas every time
    InternalStructs.RewardAndUserData storage rewardAndUserData;
    InternalStructs.RewardAddrAndDistrEnd memory rewardInfo;

    for (uint256 i; i < rewardsLength; ++i) {
      rewardInfo = assetData.rewardsInfo[i];
      rewardAndUserData = assetData.data[rewardInfo.addr];

      if (lastUpdateTimestamp < rewardInfo.distributionEnd) {
        _updateRewardIndex(
          rewardAndUserData,
          extraParamsForIndexScaled,
          asset,
          rewardInfo.addr,
          lastUpdateTimestamp
        );
      }

      if (user != address(0)) {
        _updateUserData(rewardAndUserData, asset, rewardInfo.addr, user, userBalance);
      }
    }

    _updateTimestamp(assetData, asset);
  }

  function _updateRewardIndex(
    InternalStructs.RewardAndUserData storage rewardAndUserData,
    InternalStructs.ExtraParamsForIndex memory extraParamsForIndexScaled,
    address asset,
    address reward,
    uint256 lastUpdateTimestamp
  ) internal {
    if (lastUpdateTimestamp == block.timestamp) {
      return;
    }

    InternalStructs.RewardData memory rewardData = rewardAndUserData.rewardData;

    rewardData.index += EmissionMath.calculateIndexIncrease(
      extraParamsForIndexScaled,
      rewardData.maxEmissionPerSecondScaled,
      rewardData.distributionEnd,
      lastUpdateTimestamp
    );

    if (block.timestamp >= rewardData.distributionEnd) {
      rewardData.maxEmissionPerSecondScaled = 0;
    }

    // `index` should be updated
    // `maxEmissionPerSecond` could be updated
    // `distributionEnd` and `decimalsScaling` should not be updated
    rewardAndUserData.rewardData = rewardData;

    emit RewardIndexUpdated(asset, reward, rewardData.index);
  }

  function _updateUserData(
    InternalStructs.RewardAndUserData storage rewardAndUserData,
    address asset,
    address reward,
    address user,
    uint256 userBalance
  ) internal {
    InternalStructs.UserData memory userData = rewardAndUserData.userData[user];
    InternalStructs.RewardData memory rewardData = rewardAndUserData.rewardData;

    if (userData.index == rewardData.index) {
      return;
    }

    uint112 newAccruedAmount = EmissionMath.calculateAccrued(
      rewardData.index,
      userData.index,
      userBalance
    );

    userData.accrued += newAccruedAmount;
    userData.index = rewardData.index;

    rewardAndUserData.userData[user] = userData;

    emit UserDataUpdated(
      asset,
      reward,
      user,
      userData.index,
      newAccruedAmount.scaleDown(rewardData.decimalsScaling)
    );
  }

  function _claimSelectedRewards(
    address asset,
    address[] memory rewards,
    address user,
    address receiver
  ) internal override returns (uint256[] memory) {
    InternalStructs.AssetData storage assetData = _getRewardsControllerStorage().assetsData[asset];
    uint256[] memory accruedAmounts = new uint256[](rewards.length);

    _updateData(
      assetData,
      _getExtraParamsForIndex(assetData.targetLiquidity, asset),
      asset,
      user,
      IERC4626(asset).balanceOf(user)
    );

    for (uint256 i; i < rewards.length; ++i) {
      InternalStructs.RewardAndUserData storage rewardAndUserData = assetData.data[rewards[i]];
      InternalStructs.UserData memory userData = rewardAndUserData.userData[user];

      uint8 decimalsScaling = rewardAndUserData.rewardData.decimalsScaling;
      accruedAmounts[i] = userData.accrued.scaleDown(decimalsScaling);

      if (accruedAmounts[i] == 0) {
        continue;
      }

      // virtual dust could remain here
      rewardAndUserData.userData[user].accrued -= (accruedAmounts[i].scaleUp(decimalsScaling))
        .toUint112();

      IERC20Metadata(rewards[i]).safeTransferFrom(
        rewardAndUserData.rewardPayer,
        receiver,
        accruedAmounts[i]
      );

      emit RewardClaimed(asset, rewards[i], user, receiver, accruedAmounts[i]);
    }

    return accruedAmounts;
  }

  function _validateOtherRewardEmissions(
    InternalStructs.AssetData storage assetData,
    uint256 targetLiquidity
  ) internal view {
    uint256 rewardsLength = assetData.rewardsInfo.length;

    // We will check every reward again, cause gas savings for skipping already validated rewards isn't worth the additional complexity of code
    for (uint256 i; i < rewardsLength; ++i) {
      address reward = assetData.rewardsInfo[i].addr;

      // zero means that emission has been disabled
      if (assetData.data[reward].rewardData.maxEmissionPerSecondScaled != 0) {
        EmissionMath.validateMaxEmission(
          assetData.data[reward].rewardData.maxEmissionPerSecondScaled,
          targetLiquidity
        );
      }
    }
  }

  function _getExtraParamsForIndex(
    uint256 targetLiquidity,
    address asset
  ) internal view returns (InternalStructs.ExtraParamsForIndex memory) {
    return
      InternalStructs.ExtraParamsForIndex({
        targetLiquidity: targetLiquidity,
        totalAssets: IERC4626(asset).totalAssets(),
        totalSupply: IERC4626(asset).totalSupply()
      });
  }

  function _isAssetInitialized(
    InternalStructs.AssetData storage assetData
  ) internal view returns (bool) {
    return assetData.targetLiquidity != 0;
  }

  function _isRewardInitialized(
    InternalStructs.RewardData storage rewardData
  ) internal view returns (bool) {
    return rewardData.distributionEnd != 0;
  }

  function _checkRescueGuardian() internal view override {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), IRescuable.OnlyRescueGuardian());
  }
}
