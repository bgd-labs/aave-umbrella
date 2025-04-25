// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

import {UmbrellaBasePayload} from './UmbrellaBasePayload.sol';
import {IUmbrellaEngineStructs as IStructs} from './IUmbrellaEngineStructs.sol';

import {IUmbrellaConfigEngine as IEngine} from './configEngine/IUmbrellaConfigEngine.sol';

/**
 * @title UmbrellaExtendedPayload
 * @notice A contract for advanced automated configurations, including token creation, reward setup, and slashing configurations.
 * @dev Allows creating tokens from scratch, configuring rewards, and setting `SlashingConfig`s.
 * Also supports removing slashing configurations and stopping all associated reward distributions.
 *
 * ***IMPORTANT*** Payload inheriting this `UmbrellaExtendedPayload` MUST BE STATELESS always.
 *
 * At this moment extended payload in addition to the base covering:
 *   - Complex token removals (deleting `SlashingConfig`s, stopping all reward distributions)
 *   - Complex token creations (deploying of tokens, setting `SlashingConfig`s, initializing reward distributions and setting `deficitOffset`)
 *
 * @author BGD labs
 */
abstract contract UmbrellaExtendedPayload is UmbrellaBasePayload {
  using Address for address;

  constructor(address umbrellaConfigEngine) UmbrellaBasePayload(umbrellaConfigEngine) {}

  /// @dev Functions to be overridden on the child
  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Performs the following operations:
   *   - Removes `SlashingConfig` inside `Umbrella` and corresponding reserve
   *   - Stops the distribution of all rewards set inside `RewardsController`
   *   - Sets `cooldown` to 0 and `unstakeWindow` to maximum possible value
   */
  function complexTokenRemovals() public view virtual returns (IStructs.TokenRemoval[] memory) {}

  /**
   * @notice Performs the following operations:
   *   - Creates new `UmbrellaStakeToken`s
   *   - Sets `SlashingConfig` for reserves and newly created tokens
   *   - Sets the specified rewards and `targetLiquidity` for `UmbrellaStakeToken`s
   *   - Increases `deficitOffset` if non-zero value is specified
   */
  function complexTokenCreations() public view virtual returns (IStructs.TokenSetup[] memory) {}

  /////////////////////////////////////////////////////////////////////////////////////////

  function _extendedExecute() internal override {
    IStructs.TokenRemoval[] memory complexTokenRemovalConfigs = complexTokenRemovals();
    IStructs.TokenSetup[] memory complexTokenSetupConfigs = complexTokenCreations();

    if (complexTokenRemovalConfigs.length != 0) {
      ENGINE.functionDelegateCall(
        abi.encodeWithSelector(IEngine.executeComplexRemovals.selector, complexTokenRemovalConfigs)
      );
    }

    if (complexTokenSetupConfigs.length != 0) {
      ENGINE.functionDelegateCall(
        abi.encodeWithSelector(IEngine.executeComplexCreations.selector, complexTokenSetupConfigs)
      );
    }
  }
}
