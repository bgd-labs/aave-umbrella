// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {VmSafe} from 'forge-std/Vm.sol';

import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC5267} from 'openzeppelin-contracts/contracts/interfaces/IERC5267.sol';

import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {IAToken} from 'aave-v3-origin/contracts/interfaces/IAToken.sol';
import {BaseTest} from 'aave-v3-origin-tests/extensions/stata-token/TestBase.sol';

import {StakeToken} from '../../../src/contracts/stakeToken/StakeToken.sol';
import {IRewardsController} from '../../../src/contracts/rewards/interfaces/IRewardsController.sol';
import {UmbrellaBatchHelper} from '../../../src/contracts/helpers/UmbrellaBatchHelper.sol';

import {RewardsController} from '../../../src/contracts/rewards/RewardsController.sol';
import {IRewardsStructs} from '../../../src/contracts/rewards/interfaces/IRewardsStructs.sol';

import {MockERC20Permit} from '../../stakeToken/utils/mock/MockERC20Permit.sol';

import {UmbrellaBatchHelperTestBase} from './UmbrellaBatchHelperBase.t.sol';

contract UmbrellaBatchHelperWithRewardsTestBase is UmbrellaBatchHelperTestBase {
  bytes32 private constant CLAIM_SELECTED_TYPEHASH =
    keccak256(
      'ClaimSelectedRewards(address asset,address[] rewards,address user,address receiver,address caller,uint256 nonce,uint256 deadline)'
    );

  RewardsController rewardsController;
  IERC20 unusedRewardToken;

  uint256 rewardAmount = 1e12 * 1e18;

  address someone = address(0xDEAD);

  function setUp() public virtual override {
    super.setUp();

    RewardsController rewardsControllerImpl = new RewardsController();

    proxyAdmin = address(0x5000);

    rewardsController = RewardsController(
      address(
        new TransparentUpgradeableProxy(
          address(rewardsControllerImpl),
          proxyAdmin,
          abi.encodeWithSelector(RewardsController.initialize.selector, OWNER)
        )
      )
    );

    umbrellaBatchHelper = new UmbrellaBatchHelper(address(rewardsController), defaultAdmin);

    StakeToken stakeTokenImpl = new StakeToken(IRewardsController(address(rewardsController)));

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
            15 days,
            2 days
          )
        )
      )
    );

    tokenAddressesWithStata[0] = address(stakeToken);
    tokenAddressesWithoutStata[0] = address(stakeTokenWithoutStata);

    unusedRewardToken = new MockERC20Permit('Unused Reward Token', 'UNRT');

    dealTokensToOwner();

    vm.startPrank(OWNER);

    IRewardsStructs.RewardSetupConfig[] memory rewards = new IRewardsStructs.RewardSetupConfig[](2);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: tokenAddressesWithStata[2], // aToken
      rewardPayer: OWNER,
      maxEmissionPerSecond: 1e18,
      distributionEnd: block.timestamp + 30 days
    });

    rewards[1] = IRewardsStructs.RewardSetupConfig({
      reward: address(unusedRewardToken), // Extra unused token
      rewardPayer: OWNER,
      maxEmissionPerSecond: 1e18,
      distributionEnd: block.timestamp + 30 days
    });

    rewardsController.configureAssetWithRewards(address(stakeToken), 1 * 1e18, rewards);

    IERC20(tokenAddressesWithStata[2]).approve(address(rewardsController), rewardAmount);
    IERC20(unusedRewardToken).approve(address(rewardsController), rewardAmount);

    IERC20(tokenAddressesWithoutStata[1]).approve(address(rewardsController), rewardAmount);

    rewards = new IRewardsStructs.RewardSetupConfig[](1);

    rewards[0] = IRewardsStructs.RewardSetupConfig({
      reward: tokenAddressesWithoutStata[1], // Token
      rewardPayer: OWNER,
      maxEmissionPerSecond: 1e18,
      distributionEnd: block.timestamp + 30 days
    });

    rewardsController.configureAssetWithRewards(address(stakeTokenWithoutStata), 1 * 1e18, rewards);

    IERC20(tokenAddressesWithoutStata[1]).approve(address(rewardsController), rewardAmount);

    vm.stopPrank();

    _dealStakeToken(user, address(stakeToken), 1e18);
    _dealStakeToken(user, address(stakeTokenWithoutStata), 1e18);

    skip(1 days);
  }

  function dealTokensToOwner() internal {
    deal(tokenAddressesWithStata[2], address(OWNER), rewardAmount);
    deal(address(unusedRewardToken), address(OWNER), rewardAmount);

    deal(tokenAddressesWithoutStata[1], address(OWNER), rewardAmount);
  }

  function getHashClaimSelectedWithPermit(
    address asset,
    address[] memory rewards,
    address user,
    address receiver,
    address sender,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 rewardsHash = keccak256(abi.encodePacked(rewards));

    bytes32 digest = keccak256(
      abi.encode(
        CLAIM_SELECTED_TYPEHASH,
        asset,
        rewardsHash,
        user,
        receiver,
        sender,
        nonce,
        deadline
      )
    );

    return toTypedDataHash(_domainSeparatorController(), digest);
  }

  function _domainSeparatorController() internal view returns (bytes32) {
    bytes32 hashedName = keccak256('RewardsDistributor');
    bytes32 hashedVersion = keccak256(bytes('1'));
    return
      keccak256(
        abi.encode(TYPE_HASH, hashedName, hashedVersion, block.chainid, address(rewardsController))
      );
  }
}
