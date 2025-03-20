// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {WadRayMath} from 'aave-v3-origin/contracts/protocol/libraries/math/WadRayMath.sol';

import {IUmbrellaStakeToken} from '../../src/contracts/stakeToken/interfaces/IUmbrellaStakeToken.sol';
import {IUmbrellaBatchHelper} from '../../src/contracts/helpers/interfaces/IUmbrellaBatchHelper.sol';

import {UmbrellaBatchHelperWithRewardsTestBase} from './utils/UmbrellaBatchHelperWithRewardsBase.t.sol';
import {MockERC20} from './utils/mocks/MockERC20.sol';

import {IStakeToken} from '../../src/contracts/stakeToken/interfaces/IStakeToken.sol';

contract ATokenMock {
  uint256 mul;
  uint256 div;

  mapping(address => uint256) scaledBalance;

  function balanceOf(address user) external view returns (uint256) {
    return (scaledBalance[user] * mul) / div;
  }

  function transfer(address to, uint256 value) external {
    uint256 balanceToTransfer = (value * div) / mul;

    scaledBalance[to] += balanceToTransfer;
    scaledBalance[msg.sender] -= balanceToTransfer;
  }

  function transferFrom(address from, address to, uint256 value) external {
    uint256 balanceToTransfer = (value * div) / mul;

    scaledBalance[to] += balanceToTransfer;
    scaledBalance[from] -= balanceToTransfer;
  }

  function mint(uint256 scaledValue) external {
    scaledBalance[msg.sender] += scaledValue;
  }

  function setMul(uint256 mul_) external {
    mul = mul_;
    div = 1e27;
  }

  function approve(address, uint256) external {}
}

contract UmbrellaTokenHelperWithRewards is UmbrellaBatchHelperWithRewardsTestBase {
  ATokenMock aTokenMock;

  function setUp() public override {
    super.setUp();

    aTokenMock = new ATokenMock();
  }

  // /// @dev Commented due to specific requirements and shouldn't be always tested
  // function test_findATokenIndexWithWeiLossDuringTransfer(uint256 mul) public {
  //   uint256 div = 1e27;

  //   mul = bound(mul, div, type(uint128).max);

  //   aTokenMock.setMul(mul);

  //   vm.startPrank(user);

  //   aTokenMock.mint(1e18);

  //   uint256 startSum = aTokenMock.balanceOf(user);

  //   aTokenMock.transfer(someone, startSum / 2);

  //   uint256 endSum = aTokenMock.balanceOf(user);
  //   uint256 endSomeoneSum = aTokenMock.balanceOf(someone);

  //   if (endSum + endSomeoneSum != startSum) {
  //     console.log(endSum);
  //     console.log(endSomeoneSum);
  //     console.log(endSum + endSomeoneSum);
  //     console.log(startSum);

  //     console.log('mul', mul); // found value 340282366919938463463374607853650939091

  //     revert();
  //   }
  // }

  // /**
  //  * @dev Commented due to specific requirements and shouldn't be always tested
  //  * Fuzz test, run more than 10_000_000 times and hasn't get revert, so sending whole balance to helper with zero balance should be always fine and doesn't lead to 1-2 wei loss
  //  * If helper balance isn't zero, than it's fine too, cause this means, that we always can send required amount of funds,
  //  * due to the fact that helper (for some reason) holds more funds than needed for transfer
  //  */
  // function test_precisionLoss(uint256 index, uint256 scaledBalance) external {
  //   index = bound(index, WadRayMath.RAY, type(uint128).max);
  //   scaledBalance = bound(scaledBalance, 0, type(uint128).max);

  //   uint256 amountToBeTransferred = WadRayMath.rayMul(scaledBalance, index);
  //   uint256 scaledBalanceDiff = WadRayMath.rayDiv(amountToBeTransferred, index);

  //   if (scaledBalanceDiff != scaledBalance) {
  //     console.log(scaledBalance);
  //     console.log(scaledBalanceDiff);

  //     revert();
  //   }
  // }

  function test_depositReplaceATokenWithMockWithTransferWeiLoss() public {
    mockRewardsController.registerToken(address(stakeToken));

    IStakeToken[] memory stakes = new IStakeToken[](1);
    stakes[0] = IStakeToken(address(stakeToken));

    vm.expectEmit();
    emit IUmbrellaBatchHelper.AssetPathInitialized(address(stakeToken));

    umbrellaBatchHelper.initializePath(stakes);

    // Path is initialized, so we can place new code to AToken to replace with Mock
    bytes memory aTokenCode = address(aTokenMock).code;
    vm.etch(tokenAddressesWithStata[2], aTokenCode);

    ATokenMock(tokenAddressesWithStata[2]).setMul(340282366919938463463374607853650939091); // random fuzzed value

    vm.startPrank(someone);

    ATokenMock(tokenAddressesWithStata[2]).mint(1e18);

    uint256 balance = IERC20(tokenAddressesWithStata[2]).balanceOf(someone);

    assertGt(balance, 0);

    IUmbrellaBatchHelper.IOData[] memory action = new IUmbrellaBatchHelper.IOData[](1);

    assertEq(stakeToken.balanceOf(someone), 0);

    action[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[2],
      value: balance / 2
    });

    assertEq(IERC20(tokenAddressesWithStata[2]).balanceOf(tokenAddressesWithStata[1]), 0);

    // shouldn't revert

    bytes[] memory batch = new bytes[](1);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, action[0]);

    umbrellaBatchHelper.multicall(batch);

    uint256 endBalance = IERC20(tokenAddressesWithStata[2]).balanceOf(someone);
    uint256 stataBalance = IERC20(tokenAddressesWithStata[2]).balanceOf(tokenAddressesWithStata[1]);

    // balance sum has been decreased during tx, however all available balance were transferred to stata
    assertLt(endBalance + stataBalance, balance);

    // Due to mock significant error loss some dust occur on contract after
  }

  function test_batchHelperDepositFromATokenGreaterAmount(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));

    amount = uint96(bound(amount, 1, type(uint96).max));

    _dealAToken(user, amount);

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(
      user,
      spender,
      tokenAddressesWithStata[2],
      uint256(amount) + 10,
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[2],
      value: uint256(amount) + 10,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    vm.startPrank(user);

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    assertEq(stakeToken.balanceOf(user), 1e18);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[2],
      value: uint256(amount) + 10
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[0]);

    umbrellaBatchHelper.multicall(batch);

    // cause initially rate is 1-1 we don't care about exchange rate here
    assertEq(stakeToken.balanceOf(user), 1e18 + uint256(amount));
    checkHelperBalancesAfterActions();
  }

  function test_batchHelperDepositFromATokeRevertZeroBalance(uint96 amount) public {
    mockRewardsController.registerToken(address(stakeToken));

    amount = uint96(bound(amount, 1, type(uint96).max));

    address spender = address(umbrellaBatchHelper);
    uint256 deadline = (block.timestamp + 1e6);

    IUmbrellaBatchHelper.Permit[] memory permits = new IUmbrellaBatchHelper.Permit[](1);

    bytes32 hash = getHash(
      user,
      spender,
      tokenAddressesWithStata[2],
      uint256(amount) + 10,
      0,
      deadline
    );
    (uint8 v, bytes32 r, bytes32 s) = signHash(userPrivateKey, hash);

    permits[0] = IUmbrellaBatchHelper.Permit({
      token: tokenAddressesWithStata[2],
      value: uint256(amount) + 10,
      deadline: deadline,
      v: v,
      r: r,
      s: s
    });

    vm.startPrank(user);

    IUmbrellaBatchHelper.IOData[] memory actions = new IUmbrellaBatchHelper.IOData[](1);

    assertEq(stakeToken.balanceOf(user), 1e18);

    actions[0] = IUmbrellaBatchHelper.IOData({
      stakeToken: IStakeToken(address(stakeToken)),
      edgeToken: tokenAddressesWithStata[2],
      value: uint256(amount) + 10
    });

    bytes[] memory batch = new bytes[](2);
    batch[0] = abi.encodeWithSelector(IUmbrellaBatchHelper.permit.selector, permits[0]);
    batch[1] = abi.encodeWithSelector(IUmbrellaBatchHelper.deposit.selector, actions[0]);

    vm.expectRevert(abi.encodeWithSelector(IUmbrellaBatchHelper.ZeroAmount.selector));
    umbrellaBatchHelper.multicall(batch);
  }
}
