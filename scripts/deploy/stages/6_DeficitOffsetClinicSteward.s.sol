// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';

import {Create2Utils} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {DeficitOffsetClinicSteward} from '../../../src/contracts/stewards/DeficitOffsetClinicSteward.sol';

import {UmbrellaScripts} from './3_Umbrella.s.sol';

library DeficitOffsetClinicStewardScripts {
  error ProxyNotExist();

  function deployDeficitOffsetClinicSteward(
    address transparentProxyFactory,
    IPool pool,
    address executor,
    address collector,
    address financialComittee
  ) internal returns (address) {
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
        type(DeficitOffsetClinicSteward).creationCode,
        abi.encode(umbrella, collector, executor, financialComittee)
      );
  }

  function predictDeficitOffsetClinicSteward(
    address transparentProxyFactory,
    IPool pool,
    address executor,
    address collector,
    address financialComittee
  ) internal view returns (address) {
    address umbrella = UmbrellaScripts.predictUmbrellaProxy(
      transparentProxyFactory,
      pool,
      executor,
      collector
    );

    return
      Create2Utils.computeCreate2Address(
        'v1',
        type(DeficitOffsetClinicSteward).creationCode,
        abi.encode(umbrella, collector, executor, financialComittee)
      );
  }
}
