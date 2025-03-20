// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

import {RewardsController} from '../../../src/contracts/rewards/RewardsController.sol';

library DeployRewardsController {
  error ImplementationNotExist();

  function deployRewardsControllerImpl() internal returns (address) {
    return Create2Utils.create2Deploy('v1', type(RewardsController).creationCode);
  }

  function deployRewardsControllerProxy(
    address transparentProxyFactory,
    address admin,
    address executor
  ) internal returns (address) {
    address rewardsControllerImpl = predictRewardsControllerImpl();
    require(rewardsControllerImpl.code.length != 0, ImplementationNotExist());

    return
      TransparentProxyFactory(transparentProxyFactory).createDeterministic(
        rewardsControllerImpl,
        admin,
        abi.encodeWithSelector(RewardsController.initialize.selector, executor),
        'v1'
      );
  }

  function predictRewardsControllerProxy(
    address transparentProxyFactory,
    address admin,
    address executor
  ) internal view returns (address) {
    address rewardsControllerImpl = predictRewardsControllerImpl();

    return
      TransparentProxyFactory(transparentProxyFactory).predictCreateDeterministic(
        rewardsControllerImpl,
        admin,
        abi.encodeWithSelector(RewardsController.initialize.selector, executor),
        'v1'
      );
  }

  function predictRewardsControllerImpl() internal pure returns (address) {
    return Create2Utils.computeCreate2Address('v1', type(RewardsController).creationCode);
  }
}
