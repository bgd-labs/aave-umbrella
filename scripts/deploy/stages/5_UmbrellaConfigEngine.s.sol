// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';

import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {UmbrellaConfigEngine} from '../../../src/contracts/payloads/configEngine/UmbrellaConfigEngine.sol';

import {RewardsControllerScripts} from './1_RewardsController.s.sol';
import {UmbrellaScripts} from './3_Umbrella.s.sol';

library UmbrellaConfigEngineScripts {
  error ProxyNotExist();

  function deployUmbrellaConfigEngine(
    address transparentProxyFactory,
    IPool pool,
    address executor,
    address collector
  ) internal returns (address) {
    address rewardsController = RewardsControllerScripts.predictRewardsControllerProxy(
      transparentProxyFactory,
      executor
    );

    require(rewardsController.code.length != 0, ProxyNotExist());

    address umbrella = UmbrellaScripts.predictUmbrellaProxy(
      transparentProxyFactory,
      pool,
      executor,
      collector
    );

    require(umbrella.code.length != 0, ProxyNotExist());

    return
      Create2Utils.create2Deploy(
        'v1',
        type(UmbrellaConfigEngine).creationCode,
        abi.encode(rewardsController, umbrella, executor)
      );
  }

  function predictUmbrellaConfigEngine(
    address transparentProxyFactory,
    IPool pool,
    address executor,
    address collector
  ) internal view returns (address) {
    address rewardsController = RewardsControllerScripts.predictRewardsControllerProxy(
      transparentProxyFactory,
      executor
    );

    address umbrella = UmbrellaScripts.predictUmbrellaProxy(
      transparentProxyFactory,
      pool,
      executor,
      collector
    );

    return
      Create2Utils.computeCreate2Address(
        'v1',
        type(UmbrellaConfigEngine).creationCode,
        abi.encode(rewardsController, umbrella, executor)
      );
  }
}
