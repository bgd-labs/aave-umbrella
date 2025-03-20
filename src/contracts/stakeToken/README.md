# Aave stk (StakeToken)

The `StakeToken` is a new version of the Aave Safety Module stk tokens, to be used on [Umbrella](https://governance.aave.com/t/bgd-aave-safety-module-umbrella/18366).

Technically, it is an EIP-4626 generic token value for non-rebasing erc-20 tokens, whose initial underlying in Umbrella will be [stataTokens](https://github.com/aave-dao/aave-v3-origin/blob/main/src/periphery/contracts/static-a-token/StataTokenV2.sol): wrapped Aave aTokens not rebasing, but exchange-rate based.

<br>

## Features

- Full [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626) compatibility.
- Withdrawal of funds from the vault can be carried out only after activation of cooldown after a certain time.
- On its usage in Umbrella, the `StakeToken` will usually be slashed for small amounts in an automated fashion, but slashing can happen up to the maximum value of `totalAssets() - MIN_ASSETS_REMAINING()`.
- As counterpart of the slashing risk, providing liquidity in the `StakeToken` gives rewards to users via a hooked `REWARDS_CONTROLLER`.
- Permit() support.
- The StakeToken is to be used below a transparent proxy, upgradable by the Aave governance.

See [`IERC4626StakeToken.sol`](interfaces/IERC4626StakeToken.sol) for detailed method documentation.

<br>

## Inheritance

The `StakeToken` is based on [`open-zeppelin-upgradeable`](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) contracts and with 2 custom inheritance layers:

- `ERC4626StakeTokenUpgradeable`, inheriting from OZ's `ERC4626Upgradeable`, is an abstract contract implementing the [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626) methods for an underlying asset. It provides basic functionality for the `StakeToken` without any access control or pausability.
- `StakeToken` is the main contract stitching things together, while adding `Pausable`, `Rescuable`, `Permit`, and the actual initialization.

<br>

## High-level properties

### `deposit/mint`, `redeem/withdraw`

- These functions are almost identical to the OZ implementation, including doing the exact same rounding.
- There are no deposit caps.
- The StakeToken performs internal accounting of underlying assets, to protect for any type of donation attack. Therefore, transferring underlying tokens directly to the contract (not via `deposit/mint`) will not affect the number of `totalAssets`.
- Accidentally transferred assets can can be rescued via `emergencyTokenTransfer`.
- The recipient of the `deposit/mint` can be any address except `address(0)`.
- `withdraw/redeem` mirrors `transferFrom()` mechanics: it can be made on behalf of any address that has given the appropriate amount of `allowance` to the initiator.

### `cooldown`

- To withdraw funds, users need to activate `сooldown`.
- Before funds are withdrawn from `StakeTokens`, they may be slashed, so the final amount of underlying assets can only be determined upon `redeem/withdraw`.
- After activating the `cooldown`, rewards continue to be accrued, as funds are still slashable.
- After activating `cooldown`, at least `_cooldown` seconds must pass, after which funds can be withdrawn within `_unstakeWindow` seconds. If funds have not been withdrawn during this time, the withdrawal will be blocked again.
- Re-activating the `cooldown` at any time will rewrite the last cooldown record in `_stakerCooldown`. The available balance for withdrawal and time for unlocking will be updated. Only 1 `cooldown` record can exist for each address at any time.
- The amount of `shares` available for withdrawal, `endOfCooldown` and `unstakeWindow` is determined at the moment the `cooldown` is activated. Further changes to `_cooldown` and `_unstakeWindow` will not affect existing `cooldown` activation records. The number of `shares` remains fixed, however, until the withdrawal of funds, the exchange rate of `shares` to `assets` may change as a result of slashing.
- While in active cooldown, the cooldown `amount` always reflects the minimum amount of shares held at any time within the pending cooldown period.
  - Transferring funds after the `cooldown` activation reduces the amount of shares available for withdrawal on the sender. As general rule, if the balance after the a transfer is less than was recorded at the time the cooldown was activated, it gets reduced.
  - `deposit/mint` after the `cooldown` has been activated will not affect the amount available for `redeem`
- Transfer of StakeToken is available without any `cooldown` mechanics.
- Withdrawing `amount` reduces the amount of `shares` available for withdrawal during the active cooldown by `amount`, fixed at the time the `cooldown` was activated.
- The `cooldown` can be activated by any address to which the owner of the balance has given appropriate permission. The owner can set any address as an operator, which can trigger the cooldown an unlimited number of times. This permission can also be revoked.
- Also, a `cooldown` can be triggered if the owner has issued a valid signature to a third party. The signature has a deadline check, but there is no check for the person who can call it. _The signature on `permit/depositWithPermit` and `cooldownWithPermit` use the same nonce._

### exchange rate

- The exchange rate between shares and assets is almost equivalent to the ERC4626 implementation from OZ v5.0.0. The only difference is that `totalAssets` is calculated virtually, and not through using `balanceOf`.
- The initial exchange rate will be 1 with precision of `decimals()` of the underlying asset.
- With exchange rate understood as the multiplication factor to convert from shares to assets, it decreases whenever a slashing happens.
- With exchange rate understood as the multiplication factor to convert from shares to assets, it cannot increase.

### `slash`

- The `slash` can be called by the `owner` of the contract at any time.
- The `slash` cannot reduce the number of `assets` less than the constant limit `MIN_ASSETS_REMAINING`.
- The `slash` decreases `totalAssets` amount.
- As a result, `slash` changes the behavior of the functions as follows:
  - `deposit` for the same amount of `assets` after slash will mint more amount of `shares`
  - `mint` for the same amount of `shares` after slash will require less amount of `assets` to transfer
  - `redeem` for the same amount of `shares` after slash will transfer less amount of `assets`
  - `withdraw` for the same amount of `assets` after slash will require more amount of `shares`

### rewards management

- Rewards are handled externally, in a `REWARDS_CONTROLLER` smart contract.
- The actions `transfer`, `deposit/mint`, `redeem/withdraw`, `slash` affecting accounting trigger a notification/hook on the `REWARDS_CONTROLLER`.
- The StakeToken assumes the call to `handleAction()` on REWARDS_CONTROLLER doesn't revert, and it is responsibility of the controller to properly handle the data received, and any type of internal failure.
- For more information on rewards from the `StataToken`, see **Limitations**.

#### `depositWithPermit`

[`ERC20PermitUpgradeable`](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/9a47a37c4b8ce2ac465e8656f31d32ac6fe26eaa/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol) has been added to the `StakeToken`, which added the ability to make a deposit using a valid signature and 1 tx via `permit()`.

#### `cooldownWithPermit`

Has been added to the `StakeToken`, which added the ability to trigger a `cooldown` using a valid signature.

#### Rescuable

[`Rescuable`](https://github.com/bgd-labs/solidity-utils/blob/main/src/contracts/utils/Rescuable.sol) has been applied to
the `StakeToken` which will allow the `owner()` of the corresponding `StakeToken` to rescue tokens on the contract.

#### Pausable

The `StakeToken` implements the [`PausableUpgradeable`](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/9a47a37c4b8ce2ac465e8656f31d32ac6fe26eaa/contracts/utils/PausableUpgradeable.sol) allowing `owner()` to pause the vault in case of an emergency.
As long as the vault is paused, any non-view actions (deposit/redeem/slash) are impossible.

<br>

## Limitations

- The `StakeToken` is not natively integrated into the aave protocol and therefore cannot use multiple sources of additional incentives. Additional incentives included in the `static-a-tokens` are disabled when using the `StakeTokens`. Also, although `StakeToken` will hold a large number of `StataTokens`, accounting for incentives allocated for them through various rewardControllers should not be taken into account at all. `StakeToken` cannot update or claim the list of rewards. However, rewards for providing liquidity in Aave are also provided.
- Since the `StakeToken` includes usage of a exchange rate, there is implicit mathematical unaccuracy, even if minimal and to be handled with the rounding strategy. This unaccuracy/imprecision generally should not exceed 1 wei (or minimal unit of each asset) if calculated relative to assets, but could be slightly more significant when composing multiple variables (with imprecision themselves).
- Due to the irreversible and constant increase in the exchange rate between assets and shares as a result of numerous slashes, the contract cannot work indefinitely. After some time, it may encounter an overflow error. To experience it, quite a lot of time must pass, and a large number of slashes on a significant percentage of the assets must occure. Taking this fact into account, we think that this contract must be guaranteed to have an error-free operation cycle lasting a couple of years. In the future, if the growth of the exchange rate exceeds our forecasts, we will freeze the deployed contracts and update them with new ones to avoid the problem.
- The underlying asset cannot be erc-777, due to re-entrance vulnerability and any custom erc-20 tokens (for example with dynamic/constant fees on transfer, etc).
