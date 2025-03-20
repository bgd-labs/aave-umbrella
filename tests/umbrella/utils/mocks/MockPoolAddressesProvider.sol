// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

contract MockPoolAddressesProvider {
  address private immutable _ORACLE;

  constructor(address oracle) {
    _ORACLE = oracle;
  }

  function getPriceOracle() external view returns (address) {
    return _ORACLE;
  }
}
