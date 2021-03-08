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

  constructor() {
    // initialize Uniswap Router to default address
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    // define contract manager
    manager = msg.sender;
  }

  receive() external payable {}

  fallback() external payable {}

  modifier restricted() {
      require(msg.sender == manager, "DEXAGG_MANAGER_ERROR");
      _;
  }

  function getAddress() external view returns (address contractAddress)  {
    return address(this);
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

  function approve(
    address transferAddress,
    uint transferAmount,
    address tokenAddress,
    bool transferFunds
  ) private restricted {
    // initialize IERC20 token according to provided address
    IERC20 token = IERC20(tokenAddress);
    // get ERC20 token balance on contract
    uint tokenBalance = token.balanceOf(address(this));
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET
    require (transferAmount < tokenBalance, "DEXAGG_INSUFFICIENT_BALANCE");
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET
    require(token.approve(transferAddress, transferAmount), "DEXAGG_ERC20APPROVAL_ERROR");
    if (transferFunds){
      require(token.transfer(transferAddress, transferAmount), "DEXAGG_ERC20TRANSFER_ERROR");
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
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    address toToken,
    uint deadline
  ) external payable restricted  returns (uint[] memory amounts) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      minSwapAmount = 1;
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      address[] memory tradePath = getTradePath(fromToken, toToken);
      // Approve transfer of IERC20 to uniswap router
      approve(address(uniswapRouter), tradeAmount, fromToken, false);
      amounts = uniswapRouter.swapExactTokensForTokens(tradeAmount, minSwapAmount, tradePath, address(this), deadline);
    }
    // return token from swapping
    approve(fromWallet, amounts[amounts.length - 1], toToken, true);
    return amounts;
  }

  function swapTokenforETH(
    string memory exchange,
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    uint deadline
  ) external payable restricted  returns (uint[] memory amounts) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      minSwapAmount = 1;
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      // Approve transfer of IERC20 to uniswap router
      approve(address(uniswapRouter), tradeAmount, fromToken, false);
      // Swap IERC20 for ETH token
      amounts = uniswapRouter.swapExactTokensForETH(tradeAmount, minSwapAmount, getTradePath(fromToken, uniswapRouter.WETH()), address(this), deadline);
    }
    // return token from swapping
    transferETH(fromWallet, amounts[amounts.length - 1]);
    return amounts;
  }

  function swapETHforToken(
    string memory exchange,
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address toToken,
    uint deadline
  ) external payable restricted  returns (uint[] memory amounts) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      minSwapAmount = 1;
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      address[] memory tradePath = getTradePath(uniswapRouter.WETH(), toToken);
      // Approve transfer of IERC20 to uniswap router
      amounts = uniswapRouter.swapExactETHForTokens{value: tradeAmount}(minSwapAmount, tradePath, address(this), deadline);
    }
    // return token from swapping
    approve(fromWallet, amounts[amounts.length - 1], toToken, true);
    return amounts;
  }

  function addLiquidity(
    string memory exchange,
    address payable fromWallet,
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted returns (uint amountA, uint amountB, uint liquidity) {
    // Approve transfer of tokenB to uniswap
    approve(address(uniswapRouter), amountBDesired, tokenB, false);
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      deadline = block.timestamp + 15000;
      // Approve transfer of tokenA to uniswap when not swapping ETH
      approve(address(uniswapRouter), amountADesired, tokenA, false);
      // Add two IERC20 tokens to liquidity pool
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
      // return liquidity pool tokens from staking
      approve(fromWallet, liquidity, UNISWAP_LP_ADDRESS, true);
    }
    return (amountA, amountB, liquidity);
  }

  function addLiquidityETH(
    string memory exchange,
    address payable fromWallet,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted returns (uint amountA, uint amountB, uint liquidity) {
    // Approve transfer of tokenB to uniswap
    approve(address(uniswapRouter), amountBDesired, tokenB, false);
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      deadline = block.timestamp + 15000;
      // Add one ETH and one IERC20 token to liquidity pool
      (amountA, amountB, liquidity) = uniswapRouter.addLiquidityETH{value: amountADesired}(tokenB, amountBDesired, amountBMin, amountAMin, address(this), deadline);
      // return liquidity pool tokens from staking
      approve(fromWallet, liquidity, UNISWAP_LP_ADDRESS, true);
    }
    return (amountA, amountB, liquidity);
  }

  function removeLiquidity(
    string memory exchange,
    address payable fromWallet,
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted returns (uint amountA, uint amountB) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
        // Approve transfer of uniswap LP token back to uniswap
      approve(address(uniswapRouter), liquidity, UNISWAP_LP_ADDRESS, false);
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      (amountA, amountB) = uniswapRouter.removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, address(this), deadline);
    }
    // return tokens from withdrawing liquidity
    approve(fromWallet, amountA, tokenA, true);
    approve(fromWallet, amountB, tokenB, true);
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
  ) external payable restricted returns (uint amountA, uint amountB) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
        // Approve transfer of uniswap LP token back to uniswap
      approve(address(uniswapRouter), liquidity, UNISWAP_LP_ADDRESS, false);
      //TODO: remove this for mainnet, should be replaced with frontend passed value
      deadline = block.timestamp + 15000;
      // Remove one ETH and one IERC20 token from liquidity pool
      (amountA, amountB) = uniswapRouter.removeLiquidityETH(tokenB, liquidity, amountBMin, amountAMin, address(this), deadline);
    }
    // return tokens from withdrawing liquidity
    transferETH(fromWallet, amountA);
    approve(fromWallet, amountB, tokenB, true);
    return (amountA, amountB);
  }
}
