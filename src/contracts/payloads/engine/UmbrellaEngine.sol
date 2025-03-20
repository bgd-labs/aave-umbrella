// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

import {IUmbrellaEngineStructs as IStructs} from '../IUmbrellaEngineStructs.sol';

import {IUmbrella} from '../../umbrella/interfaces/IUmbrella.sol';
import {IUmbrellaStkManager} from '../../umbrella/interfaces/IUmbrellaStkManager.sol';
import {IUmbrellaConfiguration} from '../../umbrella/interfaces/IUmbrellaConfiguration.sol';

library UmbrellaEngine {
  using Address for address;
  using SafeERC20 for IERC20;

  function executeCreateStakeTokens(IStructs.CreateStkToken[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrellaStkManager.createStakeTokens.selector,
          configs[i].stakeSetups
        )
      );
    }
  }

  function executeChangeCooldowns(IStructs.ChangeCooldown[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrellaStkManager.setCooldownStk.selector,
          configs[i].cooldownConfigs
        )
      );
    }
  }

  function executeChangeUnstakeWindow(IStructs.ChangeUnstake[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrellaStkManager.setUnstakeWindowStk.selector,
          configs[i].unstakeWindowConfigs
        )
      );
    }
  }

  function executeUpdateSlashingConfig(IStructs.UpdateConfig[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrellaConfiguration.updateSlashingConfigs.selector,
          configs[i].configUpdates
        )
      );
    }
  }

  function executeRemoveSlashingConfig(IStructs.RemoveConfig[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrellaConfiguration.removeSlashingConfigs.selector,
          configs[i].configRemovals
        )
      );
    }
  }

  function executeSetDeficitOffset(IStructs.SetDeficitOffset[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrella.setDeficitOffset.selector,
          configs[i].reserve,
          configs[i].amount
        )
      );
    }
  }

  function executeCoverPendingDeficit(IStructs.CoverDeficit[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      if (configs[i].approve) {
        address tokenForCoverage = IUmbrella(configs[i].umbrella).tokenForDeficitCoverage(
          configs[i].reserve
        );

        IERC20(tokenForCoverage).forceApprove(configs[i].umbrella, configs[i].amount);
      }

      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrella.coverPendingDeficit.selector,
          configs[i].reserve,
          configs[i].amount
        )
      );
    }
  }

  function executeCoverDeficitOffset(IStructs.CoverDeficit[] memory configs) external {
    for (uint256 i; i < configs.length; ++i) {
      if (configs[i].approve) {
        address tokenForCoverage = IUmbrella(configs[i].umbrella).tokenForDeficitCoverage(
          configs[i].reserve
        );

        IERC20(tokenForCoverage).forceApprove(configs[i].umbrella, configs[i].amount);
      }

      configs[i].umbrella.functionDelegateCall(
        abi.encodeWithSelector(
          IUmbrella.coverDeficitOffset.selector,
          configs[i].reserve,
          configs[i].amount
        )
      );
    }
  }
}
