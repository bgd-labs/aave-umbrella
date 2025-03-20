// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {UmbrellaBatchHelperTestBase} from './utils/UmbrellaBatchHelperBase.t.sol';

contract ReceiveEther {
  event Received(uint256 amount);

  receive() external payable {
    emit Received(msg.value);
  }
}

contract RescuableTests is UmbrellaBatchHelperTestBase {
  address someone = address(0xdead);

  function test_checkWhoCanRescue() public view {
    assertEq(umbrellaBatchHelper.whoCanRescue(), defaultAdmin);
  }

  function test_rescue() public {
    // will use the same token, but imagine if it's not underlying)
    deal(underlying, someone, 1 ether);

    vm.startPrank(someone);

    IERC20(underlying).transfer(address(umbrellaBatchHelper), 1 ether);

    vm.stopPrank();
    vm.startPrank(defaultAdmin);

    umbrellaBatchHelper.emergencyTokenTransfer(address(underlying), someone, 1 ether);

    assertEq(IERC20(underlying).balanceOf(address(stakeToken)), 0);
    assertEq(IERC20(underlying).balanceOf(someone), 1 ether);
  }

  function test_rescueEther() public {
    deal(address(umbrellaBatchHelper), 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(defaultAdmin);

    umbrellaBatchHelper.emergencyEtherTransfer(sendToMe, 1 ether);

    assertEq(sendToMe.balance, 1 ether);
  }

  function test_rescueFromNotAdmin(address anyone) public {
    vm.assume(anyone != defaultAdmin);

    deal(underlying, someone, 1 ether);
    deal(address(umbrellaBatchHelper), 1 ether);

    vm.startPrank(someone);

    IERC20(underlying).transfer(address(umbrellaBatchHelper), 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(anyone);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    umbrellaBatchHelper.emergencyTokenTransfer(address(underlying), someone, 1 ether);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    umbrellaBatchHelper.emergencyEtherTransfer(sendToMe, 1 ether);
  }
}
