// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC5267} from 'openzeppelin-contracts/contracts/interfaces/IERC5267.sol';

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {IAToken} from 'aave-v3-origin/contracts/interfaces/IAToken.sol';
import {BaseTest} from 'aave-v3-origin-tests/extensions/stata-token/TestBase.sol';

import {StakeToken} from '../../../src/contracts/stakeToken/StakeToken.sol';
import {IRewardsController} from '../../../src/contracts/rewards/interfaces/IRewardsController.sol';

import {IUmbrellaBatchHelper} from '../../../src/contracts/helpers/interfaces/IUmbrellaBatchHelper.sol';
import {UmbrellaBatchHelper} from '../../../src/contracts/helpers/UmbrellaBatchHelper.sol';

import {MockRewardsController} from '../../stakeToken/utils/mock/MockRewardsController.sol';

import {MockERC20Permit} from '../../stakeToken/utils/mock/MockERC20Permit.sol';

contract UmbrellaBatchHelperTestBase is BaseTest {
  StakeToken public stakeToken;
  StakeToken public stakeTokenWithWeth;
  StakeToken public stakeTokenWithoutStata;

  address defaultAdmin = address(0xAd4214);

  IERC20 nonStataUnderlying;

  MockRewardsController public mockRewardsController;

  UmbrellaBatchHelper public umbrellaBatchHelper;

  address[4] public tokenAddressesWithStata;
  address[2] public tokenAddressesWithoutStata;

  address attacker = address(0xDeadBeef);
  uint256 public someonePrivateKey = 0x4000;

  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  bytes32 public constant TYPE_HASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

  bytes32 private constant COOLDOWN_WITH_PERMIT_TYPEHASH =
    keccak256(
      'CooldownWithPermit(address user,address caller,uint256 cooldownNonce,uint256 deadline)'
    );

  error TestNotSupported();

  function setUp() public virtual override {
    super.setUp();

    proxyAdmin = address(0x5000);

    mockRewardsController = new MockRewardsController();

    StakeToken stakeTokenImpl = new StakeToken(IRewardsController(address(mockRewardsController)));

    stakeToken = StakeToken(
      address(
        new TransparentUpgradeableProxy(
          address(stakeTokenImpl),
          proxyAdmin,
          abi.encodeWithSelector(
            StakeToken.initialize.selector,
            address(stataTokenV2),
            'Stake Test',
            'stkTest',
            OWNER,
            15 days,
            2 days
          )
        )
      )
    );

    nonStataUnderlying = new MockERC20Permit('Non Stata Underlying', 'NST');

    stakeTokenWithoutStata = StakeToken(
      address(
        new TransparentUpgradeableProxy(
          address(stakeTokenImpl),
          proxyAdmin,
          abi.encodeWithSelector(
            StakeToken.initialize.selector,
            address(nonStataUnderlying),
            'Stake Test',
            'stkTest',
            OWNER,
            10 days,
            6 days
          )
        )
      )
    );

    stakeTokenWithWeth = StakeToken(
      address(
        new TransparentUpgradeableProxy(
          address(stakeTokenImpl),
          proxyAdmin,
          abi.encodeWithSelector(
            StakeToken.initialize.selector,
            address(underlying),
            'Stake Test',
            'stkTest',
            OWNER,
            10 days,
            6 days
          )
        )
      )
    );

    umbrellaBatchHelper = new UmbrellaBatchHelper(address(mockRewardsController), defaultAdmin);

    // this already supports native currency
    tokenAddressesWithStata[0] = address(stakeToken);
    tokenAddressesWithStata[1] = address(stataTokenV2);
    tokenAddressesWithStata[2] = aToken;
    tokenAddressesWithStata[3] = underlying;

    tokenAddressesWithoutStata[0] = address(stakeTokenWithoutStata);
    tokenAddressesWithoutStata[1] = address(nonStataUnderlying);
  }

  function test_zeroChecks() public {
    vm.expectRevert(abi.encodeWithSelector(IUmbrellaBatchHelper.ZeroAddress.selector));
    new UmbrellaBatchHelper(address(0), defaultAdmin);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new UmbrellaBatchHelper(address(mockRewardsController), address(0));
  }

  function _dealUnderlyingToken(address user, address stakeToken_, uint256 amount) internal {
    if (stakeToken_ == tokenAddressesWithStata[0]) {
      deal(address(underlying), user, amount);
    } else if (stakeToken_ == tokenAddressesWithoutStata[0]) {
      deal(address(nonStataUnderlying), user, amount);
    } else {
      revert TestNotSupported();
    }
  }

  function _dealAToken(address user, uint256 amount) internal {
    _dealUnderlyingToken(user, address(stakeToken), amount);

    vm.startPrank(user);

    IERC20(underlying).approve(address(contracts.poolProxy), amount);
    contracts.poolProxy.deposit(underlying, amount, user, 0);

    vm.stopPrank();
  }

  function _dealStataToken(
    address user,
    uint256 approxAmount
  ) internal returns (uint256 realAmountOfStataTokenGot) {
    uint256 underlyingAmount = stataTokenV2.convertToAssets(approxAmount);

    _dealUnderlyingToken(user, address(stakeToken), underlyingAmount);

    vm.startPrank(user);

    IERC20(underlying).approve(address(stataTokenV2), underlyingAmount);
    realAmountOfStataTokenGot = stataTokenV2.deposit(underlyingAmount, user);

    vm.stopPrank();
  }

  function _dealStakeToken(
    address user,
    address stakeToken_,
    uint256 approxAmount
  ) internal returns (uint256 realAmountOfStakeTokenGot) {
    if (stakeToken_ == tokenAddressesWithStata[0]) {
      uint256 underlyingAmount = StakeToken(stakeToken_).convertToAssets(approxAmount);

      _dealStataToken(user, underlyingAmount);

      vm.startPrank(user);

      IERC20(address(stataTokenV2)).approve(stakeToken_, underlyingAmount);
      realAmountOfStakeTokenGot = StakeToken(stakeToken_).deposit(underlyingAmount, user);

      vm.stopPrank();
    } else if (stakeToken_ == tokenAddressesWithoutStata[0]) {
      uint256 underlyingAmount = StakeToken(stakeToken_).convertToAssets(approxAmount);
      _dealUnderlyingToken(user, stakeToken_, underlyingAmount);

      vm.startPrank(user);

      IERC20(nonStataUnderlying).approve(stakeToken_, underlyingAmount);
      realAmountOfStakeTokenGot = StakeToken(stakeToken_).deposit(underlyingAmount, user);

      vm.stopPrank();
    } else {
      revert TestNotSupported();
    }
  }

  function checkHelperBalancesAfterActions() internal view {
    for (uint i; i < 4; ++i) {
      assertEq(IERC20(tokenAddressesWithStata[i]).balanceOf(address(umbrellaBatchHelper)), 0);
    }

    for (uint i; i < 2; ++i) {
      assertEq(IERC20(tokenAddressesWithoutStata[i]).balanceOf(address(umbrellaBatchHelper)), 0);
    }
  }

  function getHash(
    address user,
    address spender,
    address tokenForPermit,
    uint256 amountForPermit,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 digest = keccak256(
      abi.encode(PERMIT_TYPEHASH, user, spender, amountForPermit, nonce, deadline)
    );

    return toTypedDataHash(_domainSeparator(tokenForPermit), digest);
  }

  function getHashCooldownWithPermit(
    address tokenForPermit,
    address user,
    address caller,
    uint256 cooldownNonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 digest = keccak256(
      abi.encode(COOLDOWN_WITH_PERMIT_TYPEHASH, user, caller, cooldownNonce, deadline)
    );

    return toTypedDataHash(_domainSeparator(tokenForPermit), digest);
  }

  function signHash(
    uint256 userPrivKey,
    bytes32 hash
  ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
    return vm.sign(userPrivKey, hash);
  }

  function _domainSeparator(address token) internal view returns (bytes32) {
    bytes32 result;

    try IERC5267(token).eip712Domain() {
      (, string memory name, string memory version, , , , ) = IERC5267(token).eip712Domain();
      bytes32 hashedName = keccak256(bytes(name));
      bytes32 hashedVersion = keccak256(bytes(version));
      result = keccak256(abi.encode(TYPE_HASH, hashedName, hashedVersion, block.chainid, token));
    } catch {
      result = IAToken(token).DOMAIN_SEPARATOR();
    }

    return result;
  }

  function toTypedDataHash(
    bytes32 domainSeparator,
    bytes32 structHash
  ) internal pure returns (bytes32 digest) {
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, hex'19_01')
      mstore(add(ptr, 0x02), domainSeparator)
      mstore(add(ptr, 0x22), structHash)
      digest := keccak256(ptr, 0x42)
    }
  }
}
