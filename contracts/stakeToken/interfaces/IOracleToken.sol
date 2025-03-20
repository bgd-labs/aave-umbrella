// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IOracleToken {
  /**
   * @notice Returns the current asset price of the `UmbrellaStakeToken`.
   * @dev The price is calculated as `underlyingPrice * exchangeRate`.
   *
   * This function is not functional immediately after the creation of an `UmbrellaStakeToken`,
   * but after the creation of a `SlashingConfig` for this token within `Umbrella`.
   * The function will remain operational even after the removal of `SlashingConfig`,
   * as the `Umbrella` contract retains information about the last installed oracle.
   *
   * The function may result in a revert if the asset to shares exchange rate leads to overflow.
   *
   * This function is intended solely for off-chain calculations and is not a critical component of `Umbrella`.
   * It should not be relied upon by other systems as a primary source of price information.
   *
   * @return Current asset price
   */
  function latestAnswer() external view returns (int256);
}
