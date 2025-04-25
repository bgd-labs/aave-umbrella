// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';

import {UmbrellaPayloadSetup} from './utils/UmbrellaPayloadSetup.t.sol';

contract ReceiveEther {
  event Received(uint256 amount);

  receive() external payable {
    emit Received(msg.value);
  }
}

contract RescuableTests is UmbrellaPayloadSetup {
  function test_rescue() public {
    deal(address(underlying_1), umbrellaConfigEngine, 1 ether);

    vm.startPrank(rescueGuardian);

    IRescuable(umbrellaConfigEngine).emergencyTokenTransfer(address(underlying_1), user, 1 ether);

    assertEq(underlying_1.balanceOf(umbrellaConfigEngine), 0);
    assertEq(underlying_1.balanceOf(user), 1 ether);
  }

  function test_rescueEther() public {
    deal(umbrellaConfigEngine, 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(rescueGuardian);

    IRescuable(umbrellaConfigEngine).emergencyEtherTransfer(sendToMe, 1 ether);

    assertEq(umbrellaConfigEngine.balance, 0);
    assertEq(sendToMe.balance, 1 ether);
  }

  function test_rescueFromNotAdmin(address anyone) public {
    vm.assume(anyone != rescueGuardian);

    deal(address(underlying_1), umbrellaConfigEngine, 1 ether);
    deal(umbrellaConfigEngine, 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(anyone);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    IRescuable(umbrellaConfigEngine).emergencyTokenTransfer(address(underlying_1), user, 1 ether);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    IRescuable(umbrellaConfigEngine).emergencyEtherTransfer(sendToMe, 1 ether);
  }
}
