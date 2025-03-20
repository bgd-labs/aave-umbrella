// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IUmbrellaConfiguration} from '../umbrella/interfaces/IUmbrellaConfiguration.sol';

import {UmbrellaEngine} from './engine/UmbrellaEngine.sol';

import {IUmbrellaEngineStructs as IStructs} from './IUmbrellaEngineStructs.sol';

import {IUmbrella} from '../umbrella/interfaces/IUmbrella.sol';
import {IUmbrellaStkManager} from '../umbrella/interfaces/IUmbrellaStkManager.sol';
import {IUmbrellaConfiguration} from '../umbrella/interfaces/IUmbrellaConfiguration.sol';

import {UmbrellaBasePayload} from './UmbrellaBasePayload.sol';

abstract contract UmbrellaPayloadExtended is UmbrellaBasePayload {
  // create and setup
  // redeploy
  // remove and stop
}
