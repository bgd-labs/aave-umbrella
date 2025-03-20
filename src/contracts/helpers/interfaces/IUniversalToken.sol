// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStataTokenV2} from 'aave-v3-origin/contracts/extensions/stata-token/interfaces/IStataTokenV2.sol';

/**
 * @title IUniversalToken
 * @notice IUniversalToken is renamed interface of IStataTokenV2, because it includes the interface of a regular IERC20 token and IStataTokenV2.
 * This is necessary to avoid confusion in names inside `UmbrellaBatchHelper`, since it allows both `StataTokenV2`, `ERC20Permit` and `ERC20` calls (like transfer, approve, etc).
 * @author BGD labs
 */
interface IUniversalToken is IStataTokenV2 {

}
