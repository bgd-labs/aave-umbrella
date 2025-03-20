// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {VmSafe} from 'forge-std/Vm.sol';

import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {StakeToken} from '../../../src/contracts/stakeToken/StakeToken.sol';
import {IRewardsController} from '../../../src/contracts/rewards/interfaces/IRewardsController.sol';

import {MockERC20Permit} from './mock/MockERC20Permit.sol';
import {MockRewardsController} from './mock/MockRewardsController.sol';

contract StakeTestBase is Test {
  address public admin = vm.addr(0x1000);

  uint256 public userPrivateKey = 0x3000;
  address public user = vm.addr(userPrivateKey);

  address public someone = vm.addr(0x4000);

  address proxyAdmin = vm.addr(0x5000);
  address proxyAdminContract;

  IERC20Metadata public underlying;
  StakeToken public stakeToken;

  MockRewardsController public mockRewardsController;

  function setUp() public virtual {
    _setupProtocol();
    _setupStakeToken(address(underlying));
  }

  function _setupStakeToken(address stakeTokenUnderlying) internal {
    StakeToken stakeTokenImpl = new StakeToken(IRewardsController(address(mockRewardsController)));
    stakeToken = StakeToken(
      address(
        new TransparentUpgradeableProxy(
          address(stakeTokenImpl),
          proxyAdmin,
          abi.encodeWithSelector(
            StakeToken.initialize.selector,
            address(stakeTokenUnderlying),
            'Stake Test',
            'stkTest',
            admin,
            15 days,
            2 days
          )
        )
      )
    );

    proxyAdminContract = _predictProxyAdminAddress(address(stakeToken));
  }

  function _setupProtocol() internal {
    mockRewardsController = new MockRewardsController();

    underlying = new MockERC20Permit('MockToken', 'MTK');
  }

  function _dealUnderlying(uint256 amount, address actor) internal {
    deal(address(underlying), actor, amount);
  }

  function _deposit(
    uint256 amountOfAsset,
    address actor,
    address receiver
  ) internal returns (uint256) {
    _dealUnderlying(amountOfAsset, actor);

    vm.startPrank(actor);

    IERC20Metadata(stakeToken.asset()).approve(address(stakeToken), amountOfAsset);
    uint256 shares = stakeToken.deposit(amountOfAsset, receiver);

    vm.stopPrank();

    return shares;
  }

  function _mint(
    uint256 amountOfShares,
    address actor,
    address receiver
  ) internal returns (uint256) {
    uint256 amountOfAssets = stakeToken.previewMint(amountOfShares);

    _dealUnderlying(amountOfAssets, actor);

    vm.startPrank(actor);

    IERC20Metadata(stakeToken.asset()).approve(address(stakeToken), amountOfAssets);
    uint256 assets = stakeToken.mint(amountOfShares, receiver);

    vm.stopPrank();

    return assets;
  }

  function sharesMultiplier() internal pure returns (uint256) {
    return 10 ** _decimalsOffset();
  }

  function _decimalsOffset() internal pure returns (uint256) {
    return 0;
  }

  function getDiff(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a - b : b - a;
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
