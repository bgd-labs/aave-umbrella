// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from 'aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol';

interface IUmbrellaConfiguration {
  struct SlashingConfigUpdate {
    /// @notice Reserve which configuration should be updated
    address reserve;
    /// @notice Address of `UmbrellaStakeToken` that should be set for this reserve
    address umbrellaStake;
    /// @notice Percentage of funds slashed on top of the new deficit
    uint256 liquidationFee;
    /// @notice Oracle of `UmbrellaStakeToken`s underlying
    address umbrellaStakeUnderlyingOracle;
  }

  struct SlashingConfigRemoval {
    /// @notice Reserve which configuration is being removed
    address reserve;
    /// @notice Address of `UmbrellaStakeToken` that will be removed from this reserve
    address umbrellaStake;
  }

  struct SlashingConfig {
    /// @notice Address of `UmbrellaStakeToken`
    address umbrellaStake;
    /// @notice `UmbrellaStakeToken` underlying oracle address
    address umbrellaStakeUnderlyingOracle;
    /// @notice Percentage of funds slashed on top of the new deficit
    uint256 liquidationFee;
  }

  struct StakeTokenData {
    /// @notice Oracle for pricing an underlying assets of `UmbrellaStakeToken`
    /// @dev Remains after removal of `SlashingConfig`
    address underlyingOracle;
    /// @notice Reserve address for which this `UmbrellaStakeToken` is configured
    /// @dev Will be deleted after removal of `SlashingConfig`
    address reserve;
  }

  /**
   * @notice Event is emitted whenever a configuration is added or updated.
   * @param reserve Reserve which configuration is changed
   * @param umbrellaStake Address of `UmbrellaStakeToken`
   * @param liquidationFee Percentage of funds slashed on top of the deficit
   * @param umbrellaStakeUnderlyingOracle `UmbrellaStakeToken` underlying oracle address
   */
  event SlashingConfigurationChanged(
    address indexed reserve,
    address indexed umbrellaStake,
    uint256 liquidationFee,
    address umbrellaStakeUnderlyingOracle
  );

  /**
   * @notice Event is emitted whenever a configuration is removed.
   * @param reserve Reserve which configuration is removed
   * @param umbrellaStake Address of `UmbrellaStakeToken`
   */
  event SlashingConfigurationRemoved(address indexed reserve, address indexed umbrellaStake);

  /**
   * @notice Event is emitted whenever the `deficitOffset` is changed.
   * @param reserve Reserve which `deficitOffset` is changed
   * @param newDeficitOffset New amount of `deficitOffset`
   */
  event DeficitOffsetChanged(address indexed reserve, uint256 newDeficitOffset);

  /**
   * @notice Event is emitted whenever the `pendingDeficit` is changed.
   * @param reserve Reserve which `pendingDeficit` is changed
   * @param newPendingDeficit New amount of `pendingDeficit`
   */
  event PendingDeficitChanged(address indexed reserve, uint256 newPendingDeficit);

  /**
   * @dev Attempted to set zero address.
   */
  error ZeroAddress();

  /**
   * @dev Attempted to interact with a `UmbrellaStakeToken` that should be deployed by this `Umbrella` instance, but is not.
   */
  error InvalidStakeToken();

  /**
   * @dev Attempted to set a `UmbrellaStakeToken` that has a different number of decimals than `reserve`.
   */
  error InvalidNumberOfDecimals();

  /**
   * @dev Attempted to set `liquidationFee` greater than 100%.
   */
  error InvalidLiquidationFee();

  /**
   * @dev Attempted to get `SlashingConfig` for this `reserve` and `StakeToken`, however config doesn't exist for this pair.
   */
  error ConfigurationNotExist();

  /**
   * @dev Attempted to get price of `StakeToken` underlying, however the oracle has never been set.
   */
  error ConfigurationHasNotBeenSet();
  /**
   * @dev Attempted to set `UmbrellaStakeToken`, which is already set for another reserve.
   */
  error UmbrellaStakeAlreadySetForAnotherReserve();

  /**
   * @dev Attempted to add `reserve` to configuration, which isn't exist in the `Pool`.
   */
  error InvalidReserve();

  /**
   * @dev Attempted to set `umbrellaStakeUnderlyingOracle` that returns invalid price.
   */
  error InvalidOraclePrice();

  // DEFAULT_ADMIN_ROLE
  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Updates a set of slashing configurations.
   * @dev If the configs contain an already existing configuration, the configuration will be overwritten.
   * If install more than 1 configuration, then `slash` will not work in the current version.
   * @param slashingConfigs An array of configurations
   */
  function updateSlashingConfigs(SlashingConfigUpdate[] calldata slashingConfigs) external;

  /**
   * @notice Removes a set of slashing configurations.
   * @dev If such a config did not exist, the function does not revert.
   * @param removalPairs An array of coverage pairs (reserve:stk) to remove
   */
  function removeSlashingConfigs(SlashingConfigRemoval[] calldata removalPairs) external;

  /////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Returns all the slashing configurations, configured for a given `reserve`.
   * @param reserve Address of the `reserve`
   * @return An array of `SlashingConfig` structs
   */
  function getReserveSlashingConfigs(address reserve) external returns (SlashingConfig[] memory);

  /**
   * @notice Returns the slashing configuration for a given `UmbrellaStakeToken` in regards to a specific `reserve`.
   * @dev Reverts if `SlashingConfig` doesn't exist.
   * @param reserve Address of the `reserve`
   * @param umbrellaStake Address of the `UmbrellaStakeToken`
   * @return A `SlashingConfig` struct
   */
  function getReserveSlashingConfig(
    address reserve,
    address umbrellaStake
  ) external returns (SlashingConfig memory);

  /**
   * @notice Returns if a reserve is currently slashable or not.
   * A reserve is slashable if:
   * - there's only one stk configured for slashing
   * - if there is a non zero new deficit
   * @param reserve Address of the `reserve`
   * @return flag If `Umbrella` could slash for a given `reserve`
   * @return amount Amount of the new deficit, by which `UmbrellaStakeToken` potentially could be slashed
   */
  function isReserveSlashable(address reserve) external view returns (bool flag, uint256 amount);

  /**
   * @notice Returns the amount of deficit that can't be slashed using `UmbrellaStakeToken` funds.
   * @param reserve Address of the `reserve`
   * @return The amount of the `deficitOffset`
   */
  function getDeficitOffset(address reserve) external returns (uint256);

  /**
   * @notice Returns the amount of already slashed funds that have not yet been used for the deficit elimination.
   * @param reserve Address of the `reserve`
   * @return The amount of funds pending for deficit elimination
   */
  function getPendingDeficit(address reserve) external returns (uint256);

  /**
   * @notice Returns the `StakeTokenData` of the `umbrellaStake`.
   * @param umbrellaStake Address of the `UmbrellaStakeToken`
   * @return stakeTokenData A `StakeTokenData` struct
   */
  function getStakeTokenData(
    address umbrellaStake
  ) external view returns (StakeTokenData memory stakeTokenData);

  /**
   * @notice Returns the price of the `UmbrellaStakeToken` underlying.
   * @dev This price is used for calculations inside `Umbrella` and should not be used outside of this system.
   *
   * The underlying price is determined based on the current oracle, if the oracle has never been set, the function will revert.
   * The system retains information about the last oracle installed for a given `StakeToken`.
   *
   * If the `SlashingConfig` associated with the `StakeToken` is removed, this function will still be operational.
   * However, the results of its work are not guaranteed.
   *
   * @param umbrellaStake Address of the `UmbrellaStakeToken`
   * @return latestAnswer Price of the underlying
   */
  function latestUnderlyingAnswer(
    address umbrellaStake
  ) external view returns (int256 latestAnswer);

  /**
   * @notice Returns the Pool addresses provider.
   * @return Pool addresses provider address
   */
  function POOL_ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the address that is receiving the slashed funds.
   * @return Slashed funds recipient
   */
  function SLASHED_FUNDS_RECIPIENT() external view returns (address);

  /**
   * @notice Returns the Aave Pool for which this `Umbrella` instance is configured.
   * @return Pool address
   */
  function POOL() external view returns (IPool);
}
