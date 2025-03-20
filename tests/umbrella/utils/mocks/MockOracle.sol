// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

contract MockOracle {
  int256 _price;

  constructor(int256 price) {
    _price = price;
  }

  function setPrice(int256 price) public {
    _price = price;
  }

  function latestAnswer() public view returns (int256) {
    return _price;
  }
}
