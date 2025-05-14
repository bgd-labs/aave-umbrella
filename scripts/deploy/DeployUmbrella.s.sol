// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from 'forge-std/console.sol';

import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';

import {RewardsControllerScripts} from './stages/1_RewardsController.s.sol';
import {UmbrellaStakeTokenScripts} from './stages/2_UmbrellaStakeToken.s.sol';
import {UmbrellaScripts} from './stages/3_Umbrella.s.sol';
import {HelpersScripts} from './stages/4_Helpers.s.sol';
import {UmbrellaConfigEngineScripts} from './stages/5_UmbrellaConfigEngine.s.sol';
import {DeficitOffsetClinicStewardScripts} from './stages/6_DeficitOffsetClinicSteward.s.sol';

/**
 * @title DeployUmbrellaSystem
 * @notice Library for the entire `Umbrella` system deployment.
 *
 * @dev If the `deploy` function is called multiple times, it will log all deployed contract addresses
 * and attempt to deploy any contracts that are still missing, which can occur if a previous deployment was incomplete.
 * If a new `Pool` is specified, the script will deploy a new `Umbrella` proxy contract.
 *
 * The last three arguments must remain unchanged for the system to operate correctly.
 * Changing them may trigger a full system redeployment.
 *
 * @author BGD labs
 */
library DeployUmbrellaSystem {
  error AddressMisMatch();

  function deploy(
    IPool pool,
    address transparentProxyFactory,
    address executor,
    address collector
  ) internal {
    deploy(pool, transparentProxyFactory, executor, collector, address(0));
  }

  function deploy(
    IPool pool,
    address transparentProxyFactory,
    address executor,
    address collector,
    address financialComittee
  ) internal {
    // If the implementation or logic contract is already deployed, the deploy function will return its address instead of reverting.
    // However, if the proxy contract is already deployed, the deploy function will revert.
    // Therefore, it's necessary to check whether the proxy has already been deployed before calling deploy.

    // RewardsControllerImpl
    /////////////////////////////////////////////////////////////////////////////////////////
    address rewardsControllerImpl = RewardsControllerScripts.deployRewardsControllerImpl();
    console.log('RewardsController (Impl): ', rewardsControllerImpl);

    // RewardsControllerProxy
    /////////////////////////////////////////////////////////////////////////////////////////
    address rewardsControllerProxy = RewardsControllerScripts.predictRewardsControllerProxy(
      transparentProxyFactory,
      executor
    );
    if (rewardsControllerProxy.code.length == 0) {
      address proxy = RewardsControllerScripts.deployRewardsControllerProxy(
        transparentProxyFactory,
        executor
      );
      require(proxy == rewardsControllerProxy, AddressMisMatch());
    }

    console.log('RewardsController (Proxy): ', rewardsControllerProxy);

    // UmbrellaStakeTokenImpl
    /////////////////////////////////////////////////////////////////////////////////////////
    address umbrellaStakeTokenImpl = UmbrellaStakeTokenScripts.deployUmbrellaStakeTokenImpl(
      transparentProxyFactory,
      executor
    );
    console.log('UmbrellaStakeToken (Impl): ', umbrellaStakeTokenImpl);

    // UmbrellaImpl
    /////////////////////////////////////////////////////////////////////////////////////////
    address umbrellaImpl = UmbrellaScripts.deployUmbrellaImpl();
    console.log('Umbrella (Impl): ', umbrellaImpl);

    // UmbrellaProxy
    /////////////////////////////////////////////////////////////////////////////////////////
    address umbrellaProxy = UmbrellaScripts.predictUmbrellaProxy(
      transparentProxyFactory,
      pool,
      executor,
      collector
    );
    if (umbrellaProxy.code.length == 0) {
      address proxy = UmbrellaScripts.deployUmbrellaProxy(
        transparentProxyFactory,
        pool,
        executor,
        collector
      );
      require(proxy == umbrellaProxy, AddressMisMatch());
    }

    console.log('Umbrella (Proxy): ', umbrellaProxy);

    // DataAggregationHelper
    /////////////////////////////////////////////////////////////////////////////////////////
    address dataAggregationHelper = HelpersScripts.deployDataAggregationHelper(
      transparentProxyFactory,
      executor
    );
    console.log('DataAggregationHelper: ', dataAggregationHelper);

    // UmbrellaBatchHelper
    /////////////////////////////////////////////////////////////////////////////////////////
    address umbrellaBatchHelper = HelpersScripts.deployUmbrellaBatchHelper(
      transparentProxyFactory,
      executor
    );
    console.log('UmbrellaBatchHelper: ', umbrellaBatchHelper);

    // UmbrellaConfigEngine
    /////////////////////////////////////////////////////////////////////////////////////////
    address umbrellaConfigEngine = UmbrellaConfigEngineScripts.deployUmbrellaConfigEngine(
      transparentProxyFactory,
      pool,
      executor,
      collector
    );
    console.log('UmbrellaConfigEngine: ', umbrellaConfigEngine);

    // DeficitOffsetClinicSteward
    /////////////////////////////////////////////////////////////////////////////////////////
    if (financialComittee != address(0)) {
      // `DeficitOffsetClinicSteward` is not included in the core system and its deployment is optional
      address deficitOffsetClinicSteward = DeficitOffsetClinicStewardScripts
        .deployDeficitOffsetClinicSteward(
          transparentProxyFactory,
          pool,
          executor,
          collector,
          financialComittee
        );
      console.log('DeficitOffsetClinicSteward: ', deficitOffsetClinicSteward);
    }
  }

  function predict(
    IPool pool,
    address transparentProxyFactory,
    address executor,
    address collector
  ) internal view {
    predict(pool, transparentProxyFactory, executor, collector, address(0));
  }

  function predict(
    IPool pool,
    address transparentProxyFactory,
    address executor,
    address collector,
    address financialComittee
  ) internal view {
    console.log(
      'RewardsController (Impl): ',
      RewardsControllerScripts.predictRewardsControllerImpl()
    );

    console.log(
      'RewardsController (Proxy): ',
      RewardsControllerScripts.predictRewardsControllerProxy(transparentProxyFactory, executor)
    );

    console.log(
      'UmbrellaStakeToken (Impl): ',
      UmbrellaStakeTokenScripts.predictUmbrellaStakeTokenImpl(transparentProxyFactory, executor)
    );

    console.log('Umbrella (Impl): ', UmbrellaScripts.predictUmbrellaImpl());

    console.log(
      'Umbrella (Proxy): ',
      UmbrellaScripts.predictUmbrellaProxy(transparentProxyFactory, pool, executor, collector)
    );

    console.log(
      'DataAggregationHelper: ',
      HelpersScripts.predictDataAggregationHelper(transparentProxyFactory, executor)
    );

    console.log(
      'UmbrellaBatchHelper: ',
      HelpersScripts.predictUmbrellaBatchHelper(transparentProxyFactory, executor)
    );

    console.log(
      'UmbrellaConfigEngine: ',
      UmbrellaConfigEngineScripts.predictUmbrellaConfigEngine(
        transparentProxyFactory,
        pool,
        executor,
        collector
      )
    );

    if (financialComittee != address(0)) {
      console.log(
        'DeficitOffsetClinicSteward: ',
        DeficitOffsetClinicStewardScripts.predictDeficitOffsetClinicSteward(
          transparentProxyFactory,
          pool,
          executor,
          collector,
          financialComittee
        )
      );
    }
  }
}
