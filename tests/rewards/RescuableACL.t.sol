// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';

import {RewardsControllerBaseTest} from './utils/RewardsControllerBase.t.sol';

contract ReceiveEther {
  event Received(uint256 amount);

  receive() external payable {
    emit Received(msg.value);
  }
}

contract RescuableACLTest is RewardsControllerBaseTest {
  function test_rescue() public {
    _dealUnderlying(address(unusedReward), address(rewardsController), 1 ether);

    vm.startPrank(defaultAdmin);

    rewardsController.emergencyTokenTransfer(address(unusedReward), someone, 1 ether);

    assertEq(unusedReward.balanceOf(address(rewardsController)), 0);
    assertEq(unusedReward.balanceOf(someone), 1 ether);
  }

  function test_rescueEther() public {
    deal(address(rewardsController), 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(defaultAdmin);

    rewardsController.emergencyEtherTransfer(sendToMe, 1 ether);

    assertEq(sendToMe.balance, 1 ether);
  }

  function test_rescueFromNotAdmin(address anyone) public {
    vm.assume(anyone != defaultAdmin && anyone != proxyAdminContract);

    address sendToMe = address(new ReceiveEther());

    _dealUnderlying(address(unusedReward), address(rewardsController), 1 ether);
    deal(address(rewardsController), 1 ether);

    vm.startPrank(anyone);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    rewardsController.emergencyTokenTransfer(address(unusedReward), someone, 1 ether);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    rewardsController.emergencyEtherTransfer(sendToMe, 1 ether);
  }
}
