// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {IRewardsStructs} from '../../../../src/contracts/rewards/interfaces/IRewardsStructs.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

contract MockRewardsController is IRewardsStructs {
  mapping(address => bool) isTokenRegistered;

  address public lastUser;
  uint256 public lastUserBalance;

  uint256 public lastTotalSupply;
  uint256 public lastTotalAssets;

  error AssetNotInitialized(address asset);

  function handleAction(
    uint256 totalSupply,
    uint256 totalAssets,
    address user,
    uint256 userBalance
  ) external {
    lastUser = user;
    lastUserBalance = userBalance;

    lastTotalSupply = totalSupply;
    lastTotalAssets = totalAssets;
  }

  function registerToken(address stakeToken) external {
    isTokenRegistered[stakeToken] = true;
  }

  function getAssetData(
    address stakeToken
  ) external view returns (IRewardsStructs.AssetDataExternal memory) {
    if (isTokenRegistered[stakeToken]) {
      return
        IRewardsStructs.AssetDataExternal({
          targetLiquidity: 1_000 * IERC20Metadata(stakeToken).decimals(),
          lastUpdateTimestamp: block.timestamp
        });
    }

    return IRewardsStructs.AssetDataExternal({targetLiquidity: 0, lastUpdateTimestamp: 0});
  }
}
