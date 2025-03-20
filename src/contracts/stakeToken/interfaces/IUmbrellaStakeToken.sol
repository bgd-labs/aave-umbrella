// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStakeToken} from './IStakeToken.sol';
import {IOracleToken} from './IOracleToken.sol';

interface IUmbrellaStakeToken is IStakeToken, IOracleToken {}
