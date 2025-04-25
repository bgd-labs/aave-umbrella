// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {UmbrellaBatchHelper} from '../../../src/contracts/helpers/UmbrellaBatchHelper.sol';
import {DataAggregationHelper} from '../../../src/contracts/helpers/DataAggregationHelper.sol';

import {RewardsControllerScripts} from './1_RewardsController.s.sol';

library HelpersScripts {
  error ProxyNotExist();

  function deployDataAggregationHelper(
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
        type(DataAggregationHelper).creationCode,
        abi.encode(rewardsController, executor)
      );
  }

  function deployUmbrellaBatchHelper(
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
        type(UmbrellaBatchHelper).creationCode,
        abi.encode(rewardsController, executor)
      );
  }

  function predictDataAggregationHelper(
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
        type(DataAggregationHelper).creationCode,
        abi.encode(rewardsController, executor)
      );
  }

  function predictUmbrellaBatchHelper(
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
        type(UmbrellaBatchHelper).creationCode,
        abi.encode(rewardsController, executor)
      );
  }
}
