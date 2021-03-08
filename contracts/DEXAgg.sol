pragma solidity ^0.8.0;

//import "interfaces/IUniswapV2Router02.sol";
//imoprt "interfaces/IERC20.sol"
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IERC20.sol";

contract DEXAgg {
  address public manager;
  address public UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public ETHEREUM_ADDRESS = address(0x0);
  address public UNISWAP_LP_ADDRESS = 0xB10cf58E08b94480fCb81d341A63295eBb2062C2;

  IUniswapV2Router02 public uniswapRouter;
  mapping(string => address) public tokenAddresses;
  mapping(address => IERC20) public tokenInstances;

  constructor() {
    // initialize Uniswap Router to default address
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    // define contract manager
    manager = msg.sender;
    // TODO: ERASE BELOW FOR MAINNET LAUNCH
    updateTokenAddresses("ETH", address(0x0));
    updateTokenAddresses("DAI", 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    updateTokenAddresses("MKR", 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD);
    // uniswap lp token
    updateTokenAddresses("uniswap", UNISWAP_LP_ADDRESS);

  }

  receive() external payable {}

  fallback() external payable {}

  modifier restricted() {
      require(msg.sender == manager, "DEXAGG_MANAGER_ERROR");
      _;
  }

  function getAddress() external view returns (address payable contractAddress)  {
    return payable(this);
  }

  function updateManagerAddress(
    address newManagerAddress
  ) external {
    // TODO: Make restricted for mainnet
    manager = newManagerAddress;
  }

  function updateUniswapRouter(
    address tokenAddress
  ) external restricted {
      // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY (?)
      uniswapRouter = IUniswapV2Router02(tokenAddress);
  }

  function updateUniswapLPAddress(
    address tokenAddress
  ) external restricted {
      // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY (?)
      UNISWAP_LP_ADDRESS = tokenAddress;
  }

  function updateTokenAddresses(
    string memory tokenName,
    address tokenAddress
  ) public restricted {
    // TODO: MAKE IMMUTABLE FOR CONTRACT SECURITY
    // TODO: WE PROBABLY ONLY NEED THIS IN SMART VAULT CONTRACT, CAN THEN PASS ADDRESSES TO OTHER CONTRACTS GIVEN THINGS ARE SECURE HERE
    tokenAddresses[tokenName] = tokenAddress;
    if (keccak256(abi.encodePacked(tokenName)) != keccak256(abi.encodePacked("ETH"))) {
      tokenInstances[tokenAddress] = IERC20(tokenAddress);
    }
  }

  function approveToken(
    address transferAddress,
    uint transferAmount,
    address tokenAddress,
    bool transferFunds
  ) private restricted {
    // get ERC20 token balance on contract
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS HERE IN MAINNET (?)
    require (transferAmount < tokenInstances[tokenAddress].balanceOf(address(this)), "SMARTVAULT_APPROVEFUNDS_ERROR");
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS HERE IN MAINNET (?)
    require(tokenInstances[tokenAddress].approve(transferAddress, transferAmount), "SMARTVAULT_APPROVE_ERROR");
    if (transferFunds){
      require(tokenInstances[tokenAddress].transfer(transferAddress, transferAmount), "SMARTVAULT_ERC20TRANSFER_ERROR");
    }
  }

  function transferETH(
    address payable fromWallet,
    uint transferAmount
  ) private restricted {
      require(address(this).balance >= transferAmount, "DEXAGG_ETHTRANSFER_ERROR");
      fromWallet.transfer(transferAmount);
  }

  function getTradePath(
    address fromToken,
    address toToken
  ) private pure returns (address[] memory)  {
    // uniswap router takes trade path [tokenA, tokenB, ... tokenZ] - for now we assume are only support token path [tokenA, tokenB]
    // TODO: INCLUDE MULTI-TOKEN PATHS
    address[] memory path = new address[](2);
    path[0] = fromToken;
    path[1] = toToken;
    return path;
  }

  function swapTokenForToken(
    string memory exchange,
    address fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    address toToken,
    uint deadline
  ) external restricted returns (uint[] memory amounts) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      minSwapAmount = 1;
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      address[] memory tradePath = getTradePath(fromToken, toToken);
      // approveToken transfer of IERC20 to uniswap router
      approveToken(address(uniswapRouter), tradeAmount, fromToken, false);
      amounts = uniswapRouter.swapExactTokensForTokens(tradeAmount, minSwapAmount, tradePath, fromWallet, deadline);
    }
    return amounts;
  }

  function swapTokenforETH(
    string memory exchange,
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    uint deadline
  ) external restricted returns (uint[] memory amounts) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      minSwapAmount = 1;
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      // approveToken transfer of IERC20 to uniswap router
      approveToken(address(uniswapRouter), tradeAmount, fromToken, false);
      // Swap IERC20 for ETH token
      amounts = uniswapRouter.swapExactTokensForETH(tradeAmount, minSwapAmount, getTradePath(fromToken, uniswapRouter.WETH()), fromWallet, deadline);
    }
    return amounts;
  }

  function swapETHforToken(
    string memory exchange,
    address fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address toToken,
    uint deadline
  ) external payable restricted returns (uint[] memory amounts) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      minSwapAmount = 1;
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      address[] memory tradePath = getTradePath(uniswapRouter.WETH(), toToken);
      // Approve transfer of IERC20 to uniswap router
      amounts = uniswapRouter.swapExactETHForTokens{value: tradeAmount}(minSwapAmount, tradePath, fromWallet, deadline);
    }
    return amounts;
  }

  function addLiquidityTokens(
    string memory exchange,
    address fromWallet,
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted returns (uint amountA, uint amountB, uint liquidity) {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      // Approve transfer of tokenA to uniswap when not swapping ETH
      approveToken(address(uniswapRouter), amountADesired, tokenA, false);
      // Approve transfer of tokenB to uniswap
      approveToken(address(uniswapRouter), amountBDesired, tokenB, false);
      // Add two IERC20 tokens to liquidity pool
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, fromWallet, deadline);
      //(amountA, amountB, liquidity) = uniswapRouter.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
    }
    return (amountA, amountB, liquidity);
  }

  function addLiquidityETH(
    string memory exchange,
    address fromWallet,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted returns (uint amountA, uint amountB, uint liquidity) {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      // Approve transfer of tokenB to uniswap
      approveToken(address(uniswapRouter), amountBDesired, tokenB, false);
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidityETH{value:amountADesired}(tokenB, amountBDesired, amountBMin, amountAMin, fromWallet, deadline);
      //(amountA, amountB, liquidity) = uniswapRouter.addLiquidityETH{value:amountADesired}(tokenB, amountBDesired, amountBMin, amountAMin, address(this), deadline);
    }
    return (amountA, amountB, liquidity);
  }

  function removeLiquidityTokens(
    string memory exchange,
    address fromWallet,
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted returns (uint amountA, uint amountB) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
        // Approve transfer of uniswap LP token back to uniswap
      approveToken(address(uniswapRouter), liquidity, tokenAddresses[exchange], false);
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      (amountA, amountB) = uniswapRouter.removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, fromWallet, deadline);
    }
    return (amountA, amountB);
  }

  function removeLiquidityETH(
    string memory exchange,
    address payable fromWallet,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted returns (uint amountA, uint amountB) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
        // Approve transfer of uniswap LP token back to uniswap
      approveToken(address(uniswapRouter), liquidity, tokenAddresses[exchange], false);
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      // Remove one ETH and one IERC20 token from liquidity pool
      (amountA, amountB) = uniswapRouter.removeLiquidityETH(tokenB, liquidity, amountBMin, amountAMin, fromWallet, deadline);
    }
    return (amountA, amountB);
  }
}
