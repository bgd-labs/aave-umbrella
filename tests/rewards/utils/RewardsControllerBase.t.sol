// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'forge-std/Test.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {MockERC20_6_Decimals} from './mock/MockERC20_6_Decimals.sol';
import {MockERC20_18_Decimals} from './mock/MockERC20_18_Decimals.sol';

import {IRewardsDistributor} from '../../../src/contracts/rewards/interfaces/IRewardsDistributor.sol';
import {IRewardsController} from '../../../src/contracts/rewards/interfaces/IRewardsController.sol';
import {IRewardsStructs} from '../../../src/contracts/rewards/interfaces/IRewardsStructs.sol';

import {RewardsController} from '../../../src/contracts/rewards/RewardsController.sol';
import {StakeToken} from '../../../src/contracts/stakeToken/StakeToken.sol';

contract RewardsControllerBaseTest is Test {
  address public defaultAdmin = vm.addr(0x1000);
  address public rewardsAdmin = vm.addr(0x1001);

  address public umbrellaController = vm.addr(0x2000);

  uint256 public userPrivateKey = 0x3000;
  address public user = vm.addr(userPrivateKey);

  uint256 public someonePrivateKey = 0x4000;
  address public someone = vm.addr(someonePrivateKey);

  address public proxyAdmin = vm.addr(0x5000);
  address public proxyAdminContract;

  MockERC20_6_Decimals public underlying6Decimals;
  MockERC20_18_Decimals public underlying18Decimals;

  StakeToken public stakeWith6Decimals;
  StakeToken public stakeWith18Decimals;

  MockERC20_6_Decimals public reward6Decimals;
  MockERC20_18_Decimals public reward18Decimals;
  MockERC20_18_Decimals public unusedReward;

  RewardsController public rewardsController;

  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
  bytes32 public constant REWARDS_ADMIN_ROLE = keccak256('REWARDS_ADMIN_ROLE');

  bytes32 internal _hashedName = keccak256(bytes('RewardsDistributor'));
  bytes32 internal _hashedVersion = keccak256(bytes('1'));

  function setUp() public virtual {
    _deployRewardsController();
    _grantRole();
    _setUpTokens();
    _setUpRewardsControllerForStakeTokens();
  }

  function _deployRewardsController() internal {
    RewardsController rewardsControllerImpl = new RewardsController();

    rewardsController = RewardsController(
      address(
        new TransparentUpgradeableProxy(
          address(rewardsControllerImpl),
          proxyAdmin,
          abi.encodeWithSelector(RewardsController.initialize.selector, defaultAdmin)
        )
      )
    );

    proxyAdminContract = _predictProxyAdminAddress(address(rewardsController));
  }

  function _grantRole() internal {
    vm.startPrank(defaultAdmin);

    rewardsController.grantRole(REWARDS_ADMIN_ROLE, rewardsAdmin);

    vm.stopPrank();
  }

  function _setUpTokens() internal {
    underlying6Decimals = new MockERC20_6_Decimals('Underlying 6 decimals', 'U6D');
    underlying18Decimals = new MockERC20_18_Decimals('Underlying 18 decimals', 'U18D');

    StakeToken stakeTokenImpl = new StakeToken(IRewardsController(address(rewardsController)));

    stakeWith6Decimals = StakeToken(
      address(
        new TransparentUpgradeableProxy(
          address(stakeTokenImpl),
          proxyAdmin,
          abi.encodeWithSelector(
            StakeToken.initialize.selector,
            address(underlying6Decimals),
            'Stake Token 6 decimals',
            'stk6',
            umbrellaController,
            15 days,
            2 days
          )
        )
      )
    );

    stakeWith18Decimals = StakeToken(
      address(
        new TransparentUpgradeableProxy(
          address(stakeTokenImpl),
          proxyAdmin,
          abi.encodeWithSelector(
            StakeToken.initialize.selector,
            address(underlying18Decimals),
            'Stake Token 18 decimals',
            'stk18',
            umbrellaController,
            15 days,
            2 days
          )
        )
      )
    );

    reward6Decimals = new MockERC20_6_Decimals('Reward 6 decimals', 'R6D');
    reward18Decimals = new MockERC20_18_Decimals('Reward 18 decimals', 'R18D');
    unusedReward = new MockERC20_18_Decimals('UnusedReward', 'UnusedR');
  }

  function _setUpRewardsControllerForStakeTokens() internal {
    vm.startPrank(defaultAdmin);

    IRewardsStructs.RewardSetupConfig[] memory empty = new IRewardsStructs.RewardSetupConfig[](0);

    rewardsController.configureAssetWithRewards(
      address(stakeWith18Decimals),
      10_000_000 * 1e18,
      empty
    );

    vm.stopPrank();
  }

  function _dealUnderlying(address underlying, address receiver, uint256 amount) internal {
    deal(address(underlying), receiver, amount);
  }

  function _dealStakeToken(
    StakeToken stakeToken,
    address receiver,
    uint256 amountOfAsset
  ) internal returns (uint256) {
    _dealUnderlying(stakeToken.asset(), receiver, amountOfAsset);

    vm.startPrank(receiver);

    IERC20(stakeToken.asset()).approve(address(stakeToken), amountOfAsset);
    uint256 shares = stakeToken.deposit(amountOfAsset, receiver);

    vm.stopPrank();

    return shares;
  }

  function test_initializeZeroAddressAdmin() public {
    RewardsController rewardsControllerImpl = new RewardsController();

    vm.expectRevert(abi.encodeWithSelector(IRewardsDistributor.ZeroAddress.selector));
    rewardsController = RewardsController(
      address(
        new TransparentUpgradeableProxy(
          address(rewardsControllerImpl),
          proxyAdmin,
          abi.encodeWithSelector(RewardsController.initialize.selector, address(0))
        )
      )
    );
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
