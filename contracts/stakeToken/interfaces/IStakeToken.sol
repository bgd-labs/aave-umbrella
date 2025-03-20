// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IERC4626StakeToken} from './IERC4626StakeToken.sol';

interface IStakeToken is IERC4626StakeToken, IERC20Permit {}
