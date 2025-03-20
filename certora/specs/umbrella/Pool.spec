// Mock of AAVE-v3 pool for the Umbrella contract
methods {
    function _.eliminateReserveDeficit(address asset, uint256 amount) external =>
      eliminateReserveDeficitCVL(asset,amount) expect void;
    function _.getReserveDeficit(address asset) external => getReserveDeficitCVL(asset) expect uint256;
    function _.getPriceOracle() external => PER_CALLEE_CONSTANT;
    function _.getAssetPrice(address asset) external with (env e) => assetPriceCVL(/*calledContract,*/ asset, e.block.timestamp) expect uint256;
    function _.ADDRESSES_PROVIDER() external => addressProvider() expect address;
    function _.getReserveAToken(address asset) external => ATokenOfReserve(asset) expect address;
    /// @dev: Which calls might change the configuration map? Is it really immutable in this scope?
    function _.getConfiguration(address asset) external => configurationMap(asset) expect uint256;
}

ghost ATokenOfReserve(address /* asset */) returns address;

ghost assetPriceCVL(address /* asset */, uint256 /* timestamp */) returns uint256;

ghost configurationMap(address /* asset */) returns uint256;
persistent ghost addressProvider() returns address;

/*persistent*/ ghost mapping(address /* asset */ => uint256 /* deficit */) _reservesDeficit;

function getReserveDeficitCVL(address asset) returns uint256 {return _reservesDeficit[asset];}


ghost address eliminateReserveDeficit__asset;
ghost uint256 eliminateReserveDeficit__amount;
function eliminateReserveDeficitCVL(address asset, uint256 amount) {
  // In order to check the parameters passed to eliminateReserveDeficit(), we record them here:
  eliminateReserveDeficit__asset = asset;
  eliminateReserveDeficit__amount = amount;
  
  uint256 balanceWriteOff = _reservesDeficit[asset] < amount ? _reservesDeficit[asset] : amount;
  _reservesDeficit[asset] = assert_uint256(_reservesDeficit[asset] - balanceWriteOff);
}
