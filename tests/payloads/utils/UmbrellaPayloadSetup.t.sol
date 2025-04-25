// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import 'forge-std/Test.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

import {IUmbrellaStkManager} from '../../../src/contracts/umbrella/interfaces/IUmbrellaStkManager.sol';
import {Umbrella, IPool} from '../../../src/contracts/umbrella/Umbrella.sol';
import {RewardsController} from '../../../src/contracts/rewards/RewardsController.sol';
import {UmbrellaStakeToken} from '../../../src/contracts/stakeToken/UmbrellaStakeToken.sol';

import {UmbrellaBasePayload} from '../../../src/contracts/payloads/UmbrellaBasePayload.sol';

import {UmbrellaConfigEngine, IUmbrellaConfigEngine} from '../../../src/contracts/payloads/configEngine/UmbrellaConfigEngine.sol';

import {MockAaveOracle} from '../../umbrella/utils/mocks/MockAaveOracle.sol';
import {MockPoolAddressesProvider} from '../../umbrella/utils/mocks/MockPoolAddressesProvider.sol';
import {MockPool} from '../../umbrella/utils/mocks/MockPool.sol';

import {MockERC20_18_Decimals} from '../../rewards/utils/mock/MockERC20_18_Decimals.sol';

contract UmbrellaPayloadSetup is Test {
  address user = vm.addr(0x1000);
  address public proxyAdmin = vm.addr(0x2000);

  EXECUTOR public defaultAdmin = new EXECUTOR();
  address public rescueGuardian = vm.addr(0x3000);

  address public collector = vm.addr(0x6000);

  MockERC20_18_Decimals public underlying_1;
  MockERC20_18_Decimals public underlying_2;

  MockERC20_18_Decimals public reward;

  UmbrellaStakeToken public stakeToken_1;
  UmbrellaStakeToken public stakeToken_2;

  Umbrella public umbrella;
  RewardsController public rewardsController;

  MockPool public pool;
  MockAaveOracle public aaveOracle;
  MockPoolAddressesProvider public poolAddressesProvider;

  TransparentProxyFactory transparentProxyFactory;
  UmbrellaStakeToken umbrellaStakeTokenImpl;

  uint256 constant defaultCooldown = 2 weeks;
  uint256 constant defaultUnstakeWindow = 2 days;

  address public umbrellaConfigEngine = vm.addr(0xDEAD);

  function setUp() public virtual {
    transparentProxyFactory = new TransparentProxyFactory();

    _setupPool();
    _setupRewardsController();
    _setupUmbrella();
    _createTokens();

    _setupUmbrellaPayloads();
  }

  function _setupPool() internal {
    aaveOracle = new MockAaveOracle();
    poolAddressesProvider = new MockPoolAddressesProvider(address(aaveOracle));
    pool = new MockPool(address(poolAddressesProvider));
  }

  function _setupRewardsController() internal {
    RewardsController rewardsControllerImpl = new RewardsController();
    rewardsController = RewardsController(
      transparentProxyFactory.create(
        address(rewardsControllerImpl),
        proxyAdmin,
        abi.encodeWithSelector(RewardsController.initialize.selector, address(defaultAdmin))
      )
    );
  }

  function _setupUmbrella() internal {
    umbrellaStakeTokenImpl = new UmbrellaStakeToken(rewardsController);
    Umbrella umbrellaImpl = new Umbrella();

    umbrella = Umbrella(
      transparentProxyFactory.create(
        address(umbrellaImpl),
        proxyAdmin,
        abi.encodeWithSelector(
          Umbrella.initialize.selector,
          IPool(address(pool)),
          address(defaultAdmin),
          collector,
          umbrellaStakeTokenImpl,
          address(transparentProxyFactory)
        )
      )
    );
  }

  function _createTokens() internal {
    vm.startPrank(address(defaultAdmin));

    underlying_1 = new MockERC20_18_Decimals('M18', 'M18');
    underlying_2 = new MockERC20_18_Decimals('M18', 'M18');
    reward = new MockERC20_18_Decimals('M18', 'M18');

    IUmbrellaStkManager.StakeTokenSetup[]
      memory stakeSetups = new IUmbrellaStkManager.StakeTokenSetup[](2);
    stakeSetups[0] = IUmbrellaStkManager.StakeTokenSetup({
      underlying: address(underlying_1),
      cooldown: defaultCooldown,
      unstakeWindow: defaultUnstakeWindow,
      suffix: 'v1'
    });
    stakeSetups[1] = IUmbrellaStkManager.StakeTokenSetup({
      underlying: address(underlying_2),
      cooldown: defaultCooldown,
      unstakeWindow: defaultUnstakeWindow,
      suffix: 'v1'
    });

    address[] memory addresses = umbrella.createStakeTokens(stakeSetups);

    stakeToken_1 = UmbrellaStakeToken(addresses[0]);
    stakeToken_2 = UmbrellaStakeToken(addresses[1]);

    vm.stopPrank();
  }

  function _setupUmbrellaPayloads() internal {
    address newUmbrellaConfigEngine = address(
      new UmbrellaConfigEngine(address(rewardsController), address(umbrella), rescueGuardian)
    );

    vm.etch(umbrellaConfigEngine, newUmbrellaConfigEngine.code);
    vm.store(umbrellaConfigEngine, 0, bytes32(uint256(uint160(rescueGuardian)))); // set owner to storage slot 0

    assertEq(UmbrellaConfigEngine(umbrellaConfigEngine).UMBRELLA(), address(umbrella));
    assertEq(
      UmbrellaConfigEngine(umbrellaConfigEngine).REWARDS_CONTROLLER(),
      address(rewardsController)
    );
  }

  function test_UmbrellaConfigEngineZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(IUmbrellaConfigEngine.ZeroAddress.selector));
    address newUmbrellaConfigEngine = address(
      new UmbrellaConfigEngine(address(0), address(umbrella), rescueGuardian)
    );

    vm.expectRevert(abi.encodeWithSelector(IUmbrellaConfigEngine.ZeroAddress.selector));
    newUmbrellaConfigEngine = address(
      new UmbrellaConfigEngine(address(rewardsController), address(0), rescueGuardian)
    );
  }
}

contract EXECUTOR {
  using Address for address;

  function execute(address payload) public {
    payload.functionDelegateCall(abi.encodeWithSelector(UmbrellaBasePayload.execute.selector));
  }
}
