// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAccessControl} from 'openzeppelin-contracts/contracts/access/AccessControl.sol';

import {DeficitOffsetClinicSteward, IDeficitOffsetClinicSteward} from '../../src/contracts/stewards/DeficitOffsetClinicSteward.sol';

import {DeficitOffsetClinicStewardBase} from './utils/DeficitOffsetClinicStewardBase.t.sol';

contract DeficitOffsetClinicStewardTest is DeficitOffsetClinicStewardBase {
  function test_deploy() public {
    vm.expectRevert(abi.encodeWithSelector(IDeficitOffsetClinicSteward.ZeroAddress.selector));
    new DeficitOffsetClinicSteward(address(0), collector, defaultAdmin, financeCommittee);

    vm.expectRevert(abi.encodeWithSelector(IDeficitOffsetClinicSteward.ZeroAddress.selector));
    new DeficitOffsetClinicSteward(address(umbrella), address(0), defaultAdmin, financeCommittee);

    vm.expectRevert(abi.encodeWithSelector(IDeficitOffsetClinicSteward.ZeroAddress.selector));
    new DeficitOffsetClinicSteward(address(umbrella), collector, address(0), financeCommittee);

    vm.expectRevert(abi.encodeWithSelector(IDeficitOffsetClinicSteward.ZeroAddress.selector));
    new DeficitOffsetClinicSteward(address(umbrella), collector, defaultAdmin, address(0));
  }

  function test_setup() public {
    assertEq(umbrella.hasRole(COVERAGE_MANAGER_ROLE, address(clinicSteward)), true);

    vm.startPrank(defaultAdmin);

    umbrella.setDeficitOffset(address(underlying6Decimals), 1000 * 1e6);
    pool.addReserveDeficit(address(underlying6Decimals), 500 * 1e6);

    assertEq(clinicSteward.getDeficitOffset(address(underlying6Decimals)), 1_000 * 1e6);
    assertEq(clinicSteward.getReserveDeficit(address(underlying6Decimals)), 500 * 1e6);
    assertEq(clinicSteward.getPendingDeficit(address(underlying6Decimals)), 0);

    assertEq(clinicSteward.getDeficitOffsetToCover(address(underlying6Decimals)), 500 * 1e6);

    pool.addReserveDeficit(address(underlying6Decimals), 600 * 1e6);

    assertEq(clinicSteward.getDeficitOffset(address(underlying6Decimals)), 1_000 * 1e6);
    assertEq(clinicSteward.getReserveDeficit(address(underlying6Decimals)), 1_100 * 1e6);
    assertEq(clinicSteward.getPendingDeficit(address(underlying6Decimals)), 0);

    assertEq(clinicSteward.getDeficitOffsetToCover(address(underlying6Decimals)), 1_000 * 1e6);
  }

  function test_coverDeficitOffsetRevert() public {
    vm.prank(financeCommittee);

    vm.expectRevert(
      abi.encodeWithSelector(IDeficitOffsetClinicSteward.DeficitOffsetCannotBeCovered.selector)
    );
    clinicSteward.coverDeficitOffset(address(underlying6Decimals));

    vm.prank(defaultAdmin);

    umbrella.setDeficitOffset(address(underlying6Decimals), 1000 * 1e6);

    vm.prank(financeCommittee);
    vm.expectRevert(
      abi.encodeWithSelector(IDeficitOffsetClinicSteward.DeficitOffsetCannotBeCovered.selector)
    );
    clinicSteward.coverDeficitOffset(address(underlying6Decimals));
  }

  function test_coverDeficitOffset() public {
    vm.startPrank(defaultAdmin);

    umbrella.setDeficitOffset(address(underlying6Decimals), 1000 * 1e6);
    pool.addReserveDeficit(address(underlying6Decimals), 500 * 1e6);

    vm.stopPrank();
    vm.startPrank(collector);

    deal(address(underlying6Decimals), collector, 1_000 * 1e6);
    underlying6Decimals.approve(address(clinicSteward), 1_000 * 1e6);

    vm.stopPrank();
    vm.startPrank(financeCommittee);

    assertEq(clinicSteward.getDeficitOffset(address(underlying6Decimals)), 1_000 * 1e6);
    assertEq(clinicSteward.getReserveDeficit(address(underlying6Decimals)), 500 * 1e6);
    assertEq(clinicSteward.getPendingDeficit(address(underlying6Decimals)), 0);

    assertEq(clinicSteward.getRemainingAllowance(address(underlying6Decimals)), 1_000 * 1e6);
    assertEq(clinicSteward.getDeficitOffsetToCover(address(underlying6Decimals)), 500 * 1e6);

    uint256 amountCovered = clinicSteward.coverDeficitOffset(address(underlying6Decimals));

    assertEq(amountCovered, 500 * 1e6);

    assertEq(clinicSteward.getDeficitOffset(address(underlying6Decimals)), 500 * 1e6);
    assertEq(clinicSteward.getReserveDeficit(address(underlying6Decimals)), 0);
    assertEq(clinicSteward.getPendingDeficit(address(underlying6Decimals)), 0);

    assertEq(clinicSteward.getRemainingAllowance(address(underlying6Decimals)), 500 * 1e6);
    assertEq(clinicSteward.getDeficitOffsetToCover(address(underlying6Decimals)), 0);

    pool.addReserveDeficit(address(underlying6Decimals), 600 * 1e6);

    assertEq(clinicSteward.getDeficitOffsetToCover(address(underlying6Decimals)), 500 * 1e6);

    amountCovered = clinicSteward.coverDeficitOffset(address(underlying6Decimals));

    assertEq(amountCovered, 500 * 1e6);

    assertEq(clinicSteward.getDeficitOffset(address(underlying6Decimals)), 0);
    assertEq(clinicSteward.getReserveDeficit(address(underlying6Decimals)), 100 * 1e6);
    assertEq(clinicSteward.getPendingDeficit(address(underlying6Decimals)), 0);

    assertEq(clinicSteward.getRemainingAllowance(address(underlying6Decimals)), 0);
    assertEq(clinicSteward.getDeficitOffsetToCover(address(underlying6Decimals)), 0);
  }

  function test_onlyFinancialCommittee(address anyone) public {
    vm.assume(anyone != financeCommittee);

    vm.startPrank(anyone);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        anyone,
        FINANCE_COMMITTEE_ROLE
      )
    );
    clinicSteward.coverDeficitOffset(address(underlying6Decimals));
  }
}
