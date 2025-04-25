// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';

import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {Umbrella} from '../../../src/contracts/umbrella/Umbrella.sol';

import {UmbrellaStakeTokenScripts} from './2_UmbrellaStakeToken.s.sol';

library UmbrellaScripts {
  error ImplementationNotExist();

  function deployUmbrellaImpl() internal returns (address) {
    return Create2Utils.create2Deploy('v1', type(Umbrella).creationCode);
  }

  function deployUmbrellaProxy(
    address transparentProxyFactory,
    IPool pool,
    address executor,
    address collector
  ) internal returns (address) {
    address umbrellaImpl = predictUmbrellaImpl();
    address umbrellaStakeTokenImpl = UmbrellaStakeTokenScripts.predictUmbrellaStakeTokenImpl(
      transparentProxyFactory,
      executor
    );

    require(
      umbrellaImpl.code.length != 0 && umbrellaStakeTokenImpl.code.length != 0,
      ImplementationNotExist()
    );

    bytes memory data = abi.encodeWithSelector(
      Umbrella.initialize.selector,
      pool,
      executor,
      collector,
      umbrellaStakeTokenImpl,
      transparentProxyFactory
    );

    return
      TransparentProxyFactory(transparentProxyFactory).createDeterministic(
        umbrellaImpl,
        executor, // proxyOwner
        data,
        'v1'
      );
  }

  function predictUmbrellaImpl() internal pure returns (address) {
    return Create2Utils.computeCreate2Address('v1', type(Umbrella).creationCode);
  }

  function predictUmbrellaProxy(
    address transparentProxyFactory,
    IPool pool,
    address executor,
    address collector
  ) internal view returns (address) {
    address umbrellaImpl = predictUmbrellaImpl();
    address umbrellaStakeTokenImpl = UmbrellaStakeTokenScripts.predictUmbrellaStakeTokenImpl(
      transparentProxyFactory,
      executor
    );

    bytes memory data = abi.encodeWithSelector(
      Umbrella.initialize.selector,
      pool,
      executor,
      collector,
      umbrellaStakeTokenImpl,
      transparentProxyFactory
    );

    return
      TransparentProxyFactory(transparentProxyFactory).predictCreateDeterministic(
        umbrellaImpl,
        executor, // proxyOwner
        data,
        'v1'
      );
  }
}
