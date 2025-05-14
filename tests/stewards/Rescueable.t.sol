// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';

import {DeficitOffsetClinicStewardBase} from './utils/DeficitOffsetClinicStewardBase.t.sol';

contract RescuableACLTest is DeficitOffsetClinicStewardBase {
  function test_rescue() public {
    deal(address(underlying6Decimals), address(clinicSteward), 1 ether);

    vm.startPrank(defaultAdmin);

    clinicSteward.emergencyTokenTransfer(address(underlying6Decimals), collector, 0.5 ether);

    assertEq(underlying6Decimals.balanceOf(address(clinicSteward)), 0.5 ether);
    assertEq(underlying6Decimals.balanceOf(collector), 0.5 ether);
  }

  function test_rescueEther() public {
    deal(address(clinicSteward), 1 ether);

    vm.startPrank(defaultAdmin);

    clinicSteward.emergencyEtherTransfer(collector, 0.5 ether);

    assertEq(collector.balance, 0.5 ether);
    assertEq(address(clinicSteward).balance, 0.5 ether);
  }

  function test_rescueFromNotAdmin(address anyone) public {
    vm.assume(anyone != defaultAdmin);

    deal(address(underlying6Decimals), address(clinicSteward), 1 ether);
    deal(address(clinicSteward), 1 ether);

    vm.startPrank(anyone);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    clinicSteward.emergencyTokenTransfer(address(underlying6Decimals), collector, 1 ether);

    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    clinicSteward.emergencyEtherTransfer(collector, 1 ether);
  }
}
