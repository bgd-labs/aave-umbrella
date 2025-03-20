// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';

import {UmbrellaBaseTest} from './utils/UmbrellaBase.t.sol';

contract ReceiveEther {
  event Received(uint256 amount);

  receive() external payable {
    emit Received(msg.value);
  }
}

contract RescuableACLTest is UmbrellaBaseTest {
  function test_rescue() public {
    deal(address(underlying6Decimals), address(umbrella), 1 ether);

    vm.startPrank(defaultAdmin);

    umbrella.emergencyTokenTransfer(address(underlying6Decimals), someone, 1 ether);

    assertEq(underlying6Decimals.balanceOf(address(umbrella)), 0);
    assertEq(underlying6Decimals.balanceOf(someone), 1 ether);
  }

  function test_rescueFromStk() public {
    deal(address(underlying6Decimals), address(stakeWith6Decimals), 1 ether);

    vm.startPrank(defaultAdmin);

    umbrella.emergencyTokenTransferStk(
      address(stakeWith6Decimals),
      address(underlying6Decimals),
      someone,
      1 ether
    );

    assertEq(underlying6Decimals.balanceOf(address(umbrella)), 0);
    assertEq(underlying6Decimals.balanceOf(someone), 1 ether);
  }

  function test_rescueEther() public {
    deal(address(umbrella), 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(defaultAdmin);

    umbrella.emergencyEtherTransfer(sendToMe, 1 ether);

    assertEq(sendToMe.balance, 1 ether);
  }

  function test_rescueEtherStk() public {
    deal(address(stakeWith6Decimals), 1 ether);

    address sendToMe = address(new ReceiveEther());

    vm.stopPrank();
    vm.startPrank(defaultAdmin);

    umbrella.emergencyEtherTransferStk(address(stakeWith6Decimals), sendToMe, 1 ether);

    assertEq(sendToMe.balance, 1 ether);
  }

  function test_rescueFromNotAdmin(address anyone) public {
    vm.assume(
      anyone != defaultAdmin && anyone != transparentProxyFactory.getProxyAdmin(address(umbrella))
    );

    address sendToMe = address(new ReceiveEther());

    deal(address(underlying6Decimals), address(umbrella), 1 ether);
    deal(address(umbrella), 1 ether);

    vm.startPrank(anyone);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        anyone,
        RESCUE_GUARDIAN_ROLE
      )
    );
    umbrella.emergencyTokenTransfer(address(underlying6Decimals), someone, 1 ether);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        anyone,
        RESCUE_GUARDIAN_ROLE
      )
    );
    umbrella.emergencyEtherTransfer(sendToMe, 1 ether);
  }

  function test_rescueFromNotAdminStk(address anyone) public {
    vm.assume(
      anyone != defaultAdmin && anyone != transparentProxyFactory.getProxyAdmin(address(umbrella))
    );

    address sendToMe = address(new ReceiveEther());

    deal(address(underlying6Decimals), address(stakeWith6Decimals), 1 ether);
    deal(address(stakeWith6Decimals), 1 ether);

    vm.startPrank(anyone);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        anyone,
        RESCUE_GUARDIAN_ROLE
      )
    );
    umbrella.emergencyTokenTransferStk(
      address(stakeWith6Decimals),
      address(underlying6Decimals),
      someone,
      1 ether
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        anyone,
        RESCUE_GUARDIAN_ROLE
      )
    );
    umbrella.emergencyEtherTransferStk(address(stakeWith6Decimals), sendToMe, 1 ether);
  }

  function test_maxRescue(address token) public view {
    assertEq(umbrella.maxRescue(token), type(uint256).max);
  }
}
