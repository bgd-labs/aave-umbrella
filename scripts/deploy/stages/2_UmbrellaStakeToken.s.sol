// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {UmbrellaStakeToken} from '../../../src/contracts/stakeToken/UmbrellaStakeToken.sol';
import {IRewardsController} from '../../../src/contracts/rewards/interfaces/IRewardsController.sol';

import {RewardsControllerScripts} from './1_RewardsController.s.sol';

library UmbrellaStakeTokenScripts {
  error ProxyNotExist();

  function deployUmbrellaStakeTokenImpl(
    address transparentProxyFactory,
    address executor
  ) internal returns (address) {
    address rewardsController = RewardsControllerScripts.predictRewardsControllerProxy(
      transparentProxyFactory,
      executor
    );

    require(rewardsController.code.length != 0, ProxyNotExist());

    return
      Create2Utils.create2Deploy(
        'v1',
        type(UmbrellaStakeToken).creationCode,
        abi.encode(IRewardsController(rewardsController))
      );
  }

  function predictUmbrellaStakeTokenImpl(
    address transparentProxyFactory,
    address executor
  ) internal view returns (address) {
    address rewardsController = RewardsControllerScripts.predictRewardsControllerProxy(
      transparentProxyFactory,
      executor
    );

    return
      Create2Utils.computeCreate2Address(
        'v1',
        type(UmbrellaStakeToken).creationCode,
        abi.encode(IRewardsController(rewardsController))
      );
  }
}
