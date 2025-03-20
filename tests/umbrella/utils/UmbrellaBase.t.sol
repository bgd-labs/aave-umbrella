// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import 'forge-std/Test.sol';

import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

import {IRewardsStructs} from '../../../src/contracts/rewards/interfaces/IRewardsStructs.sol';
import {IRewardsController} from '../../../src/contracts/rewards/interfaces/IRewardsController.sol';
import {IUmbrellaStkManager} from '../../../src/contracts/umbrella/interfaces/IUmbrellaStkManager.sol';

import {UmbrellaStakeToken} from '../../../src/contracts/stakeToken/UmbrellaStakeToken.sol';
import {RewardsController} from '../../../src/contracts/rewards/RewardsController.sol';
import {Umbrella, IPool} from '../../../src/contracts/umbrella/Umbrella.sol';

import {MockAaveOracle} from './mocks/MockAaveOracle.sol';
import {MockPoolAddressesProvider} from './mocks/MockPoolAddressesProvider.sol';
import {MockPool} from './mocks/MockPool.sol';

import {MockERC20_6_Decimals} from '../../rewards/utils/mock/MockERC20_6_Decimals.sol';
import {MockERC20_18_Decimals} from '../../rewards/utils/mock/MockERC20_18_Decimals.sol';

abstract contract UmbrellaBaseTest is Test {
  address public defaultAdmin = vm.addr(0x1000);

  address public user = vm.addr(0x3000);
  address public someone = vm.addr(0x4000);

  address public collector = vm.addr(0x6000);

  MockERC20_6_Decimals public underlying6Decimals;
  MockERC20_6_Decimals public anotherUnderlying6Decimals;
  MockERC20_18_Decimals public underlying18Decimals;

  UmbrellaStakeToken public stakeWith6Decimals;
  UmbrellaStakeToken public stakeWith18Decimals;

  UmbrellaStakeToken public unusedStake;

  RewardsController public rewardsController;
  Umbrella public umbrella;

  MockPool public pool;
  MockAaveOracle public aaveOracle;
  MockPoolAddressesProvider public poolAddressesProvider;

  TransparentProxyFactory transparentProxyFactory;
  UmbrellaStakeToken umbrellaStakeTokenImpl;

  uint256 public defaultCooldown = 2 weeks;
  uint256 public defaultUnstakeWindow = 2 days;

  bytes32 public constant COVERAGE_MANAGER_ROLE = keccak256('COVERAGE_MANAGER_ROLE');
  bytes32 public constant RESCUE_GUARDIAN_ROLE = keccak256('RESCUE_GUARDIAN_ROLE');
  bytes32 public constant PAUSE_GUARDIAN_ROLE = keccak256('PAUSE_GUARDIAN_ROLE');
  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

  function setUp() public virtual {
    transparentProxyFactory = new TransparentProxyFactory();

    _setupPool();

    RewardsController rewardsControllerImpl = new RewardsController();
    rewardsController = RewardsController(
      transparentProxyFactory.create(
        address(rewardsControllerImpl),
        defaultAdmin,
        abi.encodeWithSelector(RewardsController.initialize.selector, defaultAdmin)
      )
    );
    umbrellaStakeTokenImpl = new UmbrellaStakeToken(rewardsController);

    unusedStake = UmbrellaStakeToken(
      transparentProxyFactory.create(
        address(umbrellaStakeTokenImpl),
        defaultAdmin,
        abi.encodeWithSelector(
          UmbrellaStakeToken.initialize.selector,
          address(underlying6Decimals),
          'Unused 6 decimals',
          'U6',
          address(defaultAdmin),
          defaultCooldown,
          defaultUnstakeWindow
        )
      )
    );

    Umbrella umbrellaImpl = new Umbrella();

    umbrella = Umbrella(
      transparentProxyFactory.create(
        address(umbrellaImpl),
        defaultAdmin,
        abi.encodeWithSelector(
          Umbrella.initialize.selector,
          IPool(address(pool)),
          defaultAdmin,
          collector,
          umbrellaStakeTokenImpl,
          address(transparentProxyFactory)
        )
      )
    );

    _createTokens();
  }

  function _setupPool() internal {
    aaveOracle = new MockAaveOracle();
    poolAddressesProvider = new MockPoolAddressesProvider(address(aaveOracle));
    pool = new MockPool(address(poolAddressesProvider));
  }

  function _createTokens() internal {
    vm.startPrank(defaultAdmin);

    underlying6Decimals = new MockERC20_6_Decimals('M6', 'M6');
    anotherUnderlying6Decimals = new MockERC20_6_Decimals('AM6', 'AM6');
    underlying18Decimals = new MockERC20_18_Decimals('M18', 'M18');

    IUmbrellaStkManager.StakeTokenSetup[]
      memory stakeSetups = new IUmbrellaStkManager.StakeTokenSetup[](2);
    stakeSetups[0] = IUmbrellaStkManager.StakeTokenSetup({
      underlying: address(underlying6Decimals),
      cooldown: defaultCooldown,
      unstakeWindow: defaultUnstakeWindow,
      suffix: 'v1'
    });

    stakeSetups[1] = IUmbrellaStkManager.StakeTokenSetup({
      underlying: address(underlying18Decimals),
      cooldown: defaultCooldown,
      unstakeWindow: defaultUnstakeWindow,
      suffix: 'v1'
    });

    address[] memory addresses = umbrella.createStakeTokens(stakeSetups);

    stakeWith6Decimals = UmbrellaStakeToken(addresses[0]);
    stakeWith18Decimals = UmbrellaStakeToken(addresses[1]);

    vm.stopPrank();
  }

  function _predictProxyAdminAddress(address proxy) internal pure virtual returns (address) {
    return
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                bytes1(0xd6), // RLP prefix for a list with total length 22
                bytes1(0x94), // RLP prefix for an address (20 bytes)
                proxy, // 20-byte address
                uint8(1) // 1-byte nonce
              )
            )
          )
        )
      );
  }
}
