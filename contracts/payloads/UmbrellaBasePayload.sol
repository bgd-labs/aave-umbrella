// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IUmbrellaConfiguration} from '../umbrella/interfaces/IUmbrellaConfiguration.sol';

import {IUmbrellaEngineStructs as IStructs} from './IUmbrellaEngineStructs.sol';

import {RewardsControllerEngine} from './engine/RewardsControllerEngine.sol';
import {UmbrellaEngine} from './engine/UmbrellaEngine.sol';

import {IUmbrella} from '../umbrella/interfaces/IUmbrella.sol';
import {IUmbrellaStkManager} from '../umbrella/interfaces/IUmbrellaStkManager.sol';
import {IUmbrellaConfiguration} from '../umbrella/interfaces/IUmbrellaConfiguration.sol';

/**
 * @title UmbrellaBasePayload
 * @notice Abstract contract for full Umbrella configuration in manual mode. Includes all calls that should be called by governance;
 * to configure additional calls (like pause or rescue) override `_preExecute` or `_postExecute`.
 * (If you are not sure what you want to do, try to use `UmbrellaExtendedPayload`, since it has some several ready scenarios.)
 * @author BGD labs
 */
abstract contract UmbrellaBasePayload {
  function execute() external {
    _preExecute();

    _umbrellaPayload();

    _rewardsControllerPayload();

    _postExecute();
  }

  function _umbrellaPayload() internal {
    IStructs.CreateStkToken[] memory createTokens = createStkTokens();
    IStructs.ChangeCooldown[] memory changeCooldowns = updateCooldowns();
    IStructs.ChangeUnstake[] memory changeUnstakeWindows = updateUnstakeWindows();

    IStructs.RemoveConfig[] memory removeConfigs = removeSlashingConfigs();
    IStructs.UpdateConfig[] memory updateConfigs = updateSlashingConfigs();

    IStructs.SetDeficitOffset[] memory setDeficitOffsetConfigs = setDeficitOffset();

    IStructs.CoverDeficit[] memory coverPendingDeficitConfigs = coverPendingDeficit();
    IStructs.CoverDeficit[] memory coverDeficitOffsetConfigs = coverDeficitOffset();

    // First we need to create tokens, so that in subsequent actions we can integrate them
    if (createTokens.length != 0) {
      UmbrellaEngine.executeCreateStakeTokens(createTokens);
    }

    if (changeCooldowns.length != 0) {
      UmbrellaEngine.executeChangeCooldowns(changeCooldowns);
    }

    if (changeUnstakeWindows.length != 0) {
      UmbrellaEngine.executeChangeUnstakeWindow(changeUnstakeWindows);
    }

    // Need to call remove slashing config before update due to edge case (Limitations in Umbrella README)
    if (removeConfigs.length != 0) {
      UmbrellaEngine.executeRemoveSlashingConfig(removeConfigs);
    }

    if (updateConfigs.length != 0) {
      UmbrellaEngine.executeUpdateSlashingConfig(updateConfigs);
    }

    if (setDeficitOffsetConfigs.length != 0) {
      UmbrellaEngine.executeSetDeficitOffset(setDeficitOffsetConfigs);
    }

    if (coverPendingDeficitConfigs.length != 0) {
      UmbrellaEngine.executeCoverPendingDeficit(coverPendingDeficitConfigs);
    }

    if (coverDeficitOffsetConfigs.length != 0) {
      UmbrellaEngine.executeCoverDeficitOffset(coverDeficitOffsetConfigs);
    }
  }

  function _rewardsControllerPayload() internal {
    IStructs.StakeAndRewardConfig[] memory configsForStakesAndRewards = configureStakeAndRewards();
    IStructs.RewardConfig[] memory configsForRewards = configureRewards();

    if (configsForStakesAndRewards.length != 0) {
      RewardsControllerEngine.executeConfigureStakeAndRewards(configsForStakesAndRewards);
    }

    if (configsForRewards.length != 0) {
      RewardsControllerEngine.executeConfigureRewards(configsForRewards);
    }
  }

  /////////////////////////////////////////////////////////////////////////////////////////
  /// @dev Functions to be overriden on the child

  function _preExecute() internal virtual {}

  function createStkTokens() public view virtual returns (IStructs.CreateStkToken[] memory) {}

  function updateCooldowns() public view virtual returns (IStructs.ChangeCooldown[] memory) {}

  function updateUnstakeWindows() public view virtual returns (IStructs.ChangeUnstake[] memory) {}

  function removeSlashingConfigs() public view virtual returns (IStructs.RemoveConfig[] memory) {}

  function updateSlashingConfigs() public view virtual returns (IStructs.UpdateConfig[] memory) {}

  function setDeficitOffset() public view virtual returns (IStructs.SetDeficitOffset[] memory) {}

  function coverPendingDeficit() public view virtual returns (IStructs.CoverDeficit[] memory) {}

  function coverDeficitOffset() public view virtual returns (IStructs.CoverDeficit[] memory) {}

  function configureStakeAndRewards()
    public
    view
    virtual
    returns (IStructs.StakeAndRewardConfig[] memory)
  {}

  function configureRewards() public view virtual returns (IStructs.RewardConfig[] memory) {}

  function _postExecute() internal virtual {}

  /////////////////////////////////////////////////////////////////////////////////////////
}
