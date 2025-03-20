// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {IStataTokenV2} from 'aave-v3-origin/contracts/extensions/stata-token/interfaces/IStataTokenV2.sol';
import {IAaveOracle} from 'aave-v3-origin/contracts/interfaces/IAaveOracle.sol';
import {IAToken} from 'aave-v3-origin/contracts/interfaces/IAToken.sol';

import {IUmbrellaStakeToken} from '../stakeToken/interfaces/IUmbrellaStakeToken.sol';
import {IRewardsController} from '../rewards/interfaces/IRewardsController.sol';
import {IUmbrella} from '../umbrella/interfaces/IUmbrella.sol';

/**
 * @title DataAggregationHelper
 * @notice DataAggregationHelper is a utility contract designed to help getting all necessary data for frontend.
 * @author BGD labs
 */
contract DataAggregationHelper {
  struct StakeTokenData {
    TokenData stakeTokenData;
    uint256 totalAssets;
    RewardTokenData[] rewardsTokenData;
  }

  struct RewardTokenData {
    TokenData rewardTokenData;
    uint256 currentEmissionPerSecondScaled;
  }

  struct TokenData {
    address token;
    uint256 price;
    string name;
    string symbol;
    uint8 decimals;
  }

  struct StakeTokenUserData {
    address stakeToken;
    uint256 userBalance;
    RewardTokenUserData[] rewardsTokenUserData;
  }

  struct RewardTokenUserData {
    address reward;
    uint256 currentReward;
  }

  function getAllAggregatedData(
    address umbrella,
    address rewardsController,
    address aaveOracle,
    address user
  ) external view returns (StakeTokenData[] memory, StakeTokenUserData[] memory) {
    address[] memory stakeTokens = IUmbrella(umbrella).getStkTokens();

    StakeTokenData[] memory tokenData = _getTokenAggregatedData(
      stakeTokens,
      rewardsController,
      aaveOracle
    );

    StakeTokenUserData[] memory userData;

    if (user != address(0)) {
      userData = _getUserAggregatedData(stakeTokens, rewardsController, user);
    }

    return (tokenData, userData);
  }

  function getTokenAggregatedData(
    address umbrella,
    address rewardsController,
    address aaveOracle
  ) external view returns (StakeTokenData[] memory) {
    address[] memory stakeTokens = IUmbrella(umbrella).getStkTokens();

    return _getTokenAggregatedData(stakeTokens, rewardsController, aaveOracle);
  }

  function getUserAggregatedData(
    address umbrella,
    address rewardsController,
    address user
  ) external view returns (StakeTokenUserData[] memory) {
    address[] memory stakeTokens = IUmbrella(umbrella).getStkTokens();

    return _getUserAggregatedData(stakeTokens, rewardsController, user);
  }

  function _getTokenAggregatedData(
    address[] memory stakeTokens,
    address rewardsController,
    address aaveOracle
  ) internal view returns (StakeTokenData[] memory) {
    StakeTokenData[] memory stakeTokensData = new StakeTokenData[](stakeTokens.length);

    for (uint256 i; i < stakeTokens.length; ++i) {
      stakeTokensData[i].stakeTokenData = TokenData({
        token: stakeTokens[i],
        price: uint256(IUmbrellaStakeToken(stakeTokens[i]).latestAnswer()),
        name: IERC20Metadata(stakeTokens[i]).name(),
        symbol: IERC20Metadata(stakeTokens[i]).symbol(),
        decimals: IERC20Metadata(stakeTokens[i]).decimals()
      });
      stakeTokensData[i].totalAssets = IUmbrellaStakeToken(stakeTokens[i]).totalAssets();

      address[] memory rewards = IRewardsController(rewardsController).getAllRewards(
        stakeTokens[i]
      );
      stakeTokensData[i].rewardsTokenData = new RewardTokenData[](rewards.length);

      for (uint256 j; j < rewards.length; ++j) {
        // Top reward cases:
        // 1) aToken
        // 2) Token
        // 3) StataToken (should be only in rare cases)
        // return max otherwise, cause source of price isn't known
        address tokenToAskPriceFor = rewards[j];
        uint256 price;

        // aToken
        try IAToken(rewards[j]).UNDERLYING_ASSET_ADDRESS() returns (address token) {
          tokenToAskPriceFor = token;
        } catch {}

        // Token || aToken
        // price of `aToken` is equal to price of `Token`, cause backed 1-1
        try IAaveOracle(aaveOracle).getAssetPrice(tokenToAskPriceFor) returns (
          uint256 reservePrice
        ) {
          price = reservePrice;
        } catch {
          // `StataToken`, if this `Stata` isn't even from this `Pool` it will anyway return actual price
          try IStataTokenV2(rewards[j]).aToken() {
            price = uint256(IStataTokenV2(rewards[j]).latestAnswer());
          } catch {
            // Source of price isn't known, it's a `Token/aToken` or another type of `Token` except `StataToken`, that isn't listed on this concrete Aave `Pool`
            // Don't make revert here, cause it's a normal situation and this price should be get from somewhere else
            price = type(uint256).max;
          }
        }

        stakeTokensData[i].rewardsTokenData[j].rewardTokenData = TokenData({
          token: rewards[j],
          price: price,
          name: IERC20Metadata(rewards[j]).name(),
          symbol: IERC20Metadata(rewards[j]).symbol(),
          decimals: IERC20Metadata(rewards[j]).decimals()
        });

        stakeTokensData[i].rewardsTokenData[j].currentEmissionPerSecondScaled = IRewardsController(
          rewardsController
        ).calculateCurrentEmissionScaled(stakeTokens[i], rewards[j]);
      }
    }

    return stakeTokensData;
  }

  function _getUserAggregatedData(
    address[] memory stakeTokens,
    address rewardsController,
    address user
  ) internal view returns (StakeTokenUserData[] memory) {
    StakeTokenUserData[] memory stakeTokensUserData = new StakeTokenUserData[](stakeTokens.length);

    for (uint256 i; i < stakeTokens.length; ++i) {
      stakeTokensUserData[i].stakeToken = stakeTokens[i];
      stakeTokensUserData[i].userBalance = IERC20(stakeTokens[i]).balanceOf(user);

      address[] memory rewards = IRewardsController(rewardsController).getAllRewards(
        stakeTokens[i]
      );
      stakeTokensUserData[i].rewardsTokenUserData = new RewardTokenUserData[](rewards.length);

      for (uint256 j; j < rewards.length; ++j) {
        stakeTokensUserData[i].rewardsTokenUserData[j] = RewardTokenUserData({
          reward: rewards[j],
          currentReward: IRewardsController(rewardsController).calculateCurrentUserReward(
            stakeTokens[i],
            rewards[j],
            user
          )
        });
      }
    }

    return stakeTokensUserData;
  }
}
