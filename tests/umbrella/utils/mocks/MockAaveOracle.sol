// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

contract MockAaveOracle {
  mapping(address reserve => uint256 price) _prices;

  function setAssetPrice(address reserve, uint256 price) external {
    _prices[reserve] = price;
  }

  function getAssetPrice(address reserve) external view returns (uint256) {
    return _prices[reserve];
  }
}
