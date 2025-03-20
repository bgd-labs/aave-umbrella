// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IPool, DataTypes} from 'aave-v3-origin/contracts/interfaces/IPool.sol';
import {ReserveConfiguration} from 'aave-v3-origin/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {MockERC20Permit} from '../../../stakeToken/utils/mock/MockERC20Permit.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

interface IMockPool {
  function getReserveDeficit(address reserve) external view returns (uint256);

  function eliminateReserveDeficit(address reserve, uint256 amount) external returns (uint256);

  function ADDRESSES_PROVIDER() external returns (address);
}

contract MockPool is IMockPool {
  using SafeERC20 for IERC20;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  address private immutable _POOL_ADDRESSES_PROVIDER;

  mapping(address reserve => uint256 deficit) _deficit;
  mapping(address reserve => address aTokens) _aTokens;
  mapping(address reserve => DataTypes.ReserveConfigurationMap config) _configs;

  bool deactivateReserve;

  constructor(address mockPoolAddressesProvider) {
    _POOL_ADDRESSES_PROVIDER = mockPoolAddressesProvider;
  }

  function ADDRESSES_PROVIDER() external view returns (address) {
    return _POOL_ADDRESSES_PROVIDER;
  }

  function addReserveDeficit(address reserve, uint256 amount) external {
    _deficit[reserve] += amount;
  }

  function eliminateReserveDeficit(address reserve, uint256 amount) external returns (uint256) {
    if (_isVirtualAcc(reserve)) {
      MockERC20Permit(_aTokens[reserve]).burn(msg.sender, amount);
    } else {
      IERC20(reserve).safeTransferFrom(msg.sender, address(this), amount);
    }

    _deficit[reserve] -= amount;
    return amount;
  }

  function activateVirtualAcc(address reserve, bool flag) external {
    DataTypes.ReserveConfigurationMap memory config = DataTypes.ReserveConfigurationMap(0);

    config.setVirtualAccActive(flag);

    _configs[reserve] = config;
  }

  function setATokenForReserve(address reserve, address aToken) external {
    _aTokens[reserve] = aToken;
  }

  function getReserveDeficit(address reserve) external view returns (uint256) {
    return _deficit[reserve];
  }

  function getConfiguration(
    address reserve
  ) external view returns (DataTypes.ReserveConfigurationMap memory) {
    uint256 add = deactivateReserve ? 0 : 1;
    return DataTypes.ReserveConfigurationMap(_configs[reserve].data + add);
  }

  function getReserveAToken(address reserve) external view returns (address) {
    return _aTokens[reserve];
  }

  function _isVirtualAcc(address reserve) internal view returns (bool) {
    return _configs[reserve].getIsVirtualAccActive();
  }

  function switchReserve() external {
    deactivateReserve = true;
  }
}
