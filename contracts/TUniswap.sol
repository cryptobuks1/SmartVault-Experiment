pragma solidity ^0.8.0;

//import "interfaces/IUniswapV2Router02.sol";
//imoprt "interfaces/IERC20.sol"
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IERC20.sol";

contract TUniswap {
  address public manager;
  address public UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ;
  IUniswapV2Router02 public uniswapRouter;
  mapping(string => address) public tokenAddresses;

  constructor() {
    // initialize Uniswap Router to default address
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    // define contract manager
    manager = msg.sender;
    // Define uniswap WETH address for ETH token address for smooth interaction with uniswap interface
    updateTokenAddresses("ETH", uniswapRouter.WETH());
    // TODO: ERASE BELOW FOR MAINNET LAUNCH
    updateTokenAddresses("DAI", 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    updateTokenAddresses("MKR", 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD);
    updateTokenAddresses("uniswap-LP", 0xB10cf58E08b94480fCb81d341A63295eBb2062C2);
  }

  receive() external payable {}

  fallback() external payable {}

  modifier restricted() {
      require(msg.sender == manager, "TUNISWAP_MANAGER_ERROR");
      _;
  }

  modifier validTokens(
    string memory tokenA,
    string memory tokenB
  ) {
    require(tokenAddresses[tokenA] != tokenAddresses[tokenB], "TUNISWAP_TOKENMATCH_ERROR");
    require(tokenAddresses[tokenA] != address(0x0) && tokenAddresses[tokenB] != address(0x0), "TUNISWAP_TOKENEXIST_ERROR");
    _;
  }

  function getAddress() external view returns (address contractAddress)  {
    return address(this);
  }

  function updateUniswapRouter(
    address tokenAddress
  ) external restricted {
      // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY
      uniswapRouter = IUniswapV2Router02(tokenAddress);
  }

  function updateTokenAddresses(
    string memory tokenName,
    address tokenAddress
  ) public restricted {
    // TODO: MAKE IMMUTABLE FOR CONTRACT SECURITY
    tokenAddresses[tokenName] = tokenAddress;
  }

  function approve(
    uint transferAmount,
    string memory tokenName,
    bool transferFunds
  ) private restricted {
    // initialize IERC20 token according to provided address
    IERC20 token = IERC20(tokenAddresses[tokenName]);
    // get ERC20 token balance on contract
    uint tokenBalance = token.balanceOf(address(this));
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET
    require (transferAmount < tokenBalance, "TUNISWAP_INSUFFICIENT_BALANCE");
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET
    require(token.approve(address(uniswapRouter), transferAmount), "TUNISWAP_ERC20APPROVAL_ERROR");
    if (transferFunds){
      require(token.transfer(address(uniswapRouter), transferAmount), "TUNISWAP_ERC20TRANSFER_ERROR");
    }
  }

  function transfer(
    address payable fromWallet,
    string memory tokenName,
    uint transferAmount
  ) private restricted {
    if (tokenAddresses[tokenName] == tokenAddresses["ETH"]) {
      // Do directly if transfer is ETH
      require(address(this).balance >= transferAmount, "TUNISWAP_ETHTRANSFER_ERROR");
      fromWallet.transfer(transferAmount);
    } else{
      // Do ERC20 approve w/ transfer=True
      approve(transferAmount, tokenName, true);
    }
  }

  function getTradePath(
    string memory fromToken,
    string memory toToken
  ) private view validTokens(fromToken, toToken) returns (address[] memory)  {
    // uniswap router takes trade path [tokenA, tokenB, ... tokenZ] - for now we assume are only support token path [tokenA, tokenB]
    // TODO: INCLUDE MULTI-TOKEN PATHS
    address[] memory path = new address[](2);
    path[0] = tokenAddresses[fromToken];
    path[1] = tokenAddresses[toToken];
    return path;
  }

  function swapTokens(
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    string memory toToken,
    uint deadline
  ) external payable restricted validTokens(fromToken, toToken) returns (uint[] memory amounts) {
    address[] memory tradePath = getTradePath(fromToken, toToken);
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    minSwapAmount = 1;
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    deadline = block.timestamp + 15000;
    if (tradePath[0] != tokenAddresses["ETH"]) {
      // Approve transfer of IERC20 to uniswap router
      approve(tradeAmount, fromToken, false);
      if (tradePath[1] != tokenAddresses["ETH"]) {
        // Swap IERC20 for IERC20 token
        uniswapRouter.swapExactTokensForTokens(tradeAmount, minSwapAmount, tradePath, address(this), deadline);
      }
      else{
        // Swap IERC20 for ETH token
        uniswapRouter.swapExactTokensForETH(tradeAmount, minSwapAmount, tradePath, address(this), deadline);
      }
    } else  {
      // Swap ETH for IERC20 token
      uniswapRouter.swapExactETHForTokens{value: tradeAmount}(minSwapAmount, tradePath, address(this), deadline);
    }
    // return token from swapping
    transfer(fromWallet, toToken, amounts[1]);
    return amounts;
  }

  function addLiquidity(
    address payable fromWallet,
    string memory tokenA,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted validTokens(tokenA, tokenB) returns (uint amountA, uint amountB, uint liquidity) {
    // Approve transfer of tokenB to uniswap
    approve(amountBDesired, tokenB, false);
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    deadline = block.timestamp + 15000;
    if (tokenAddresses[tokenA] != tokenAddresses["ETH"]) {
      // Approve transfer of tokenA to uniswap when not swapping ETH
      approve(amountADesired, tokenA, false);
      // Add two IERC20 tokens to liquidity pool
      uniswapRouter.addLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
    } else  {
      // Add one ETH and one IERC20 token to liquidity pool
      uniswapRouter.addLiquidityETH{value: amountADesired}(tokenAddresses[tokenB], amountBDesired, amountBMin, amountAMin, address(this), deadline);
    }
    // return liquidity pool tokens from staking
    transfer(fromWallet, "uniswap-LP", liquidity);
    return (amountA, amountB, liquidity);
  }

  function removeLiquidity(
    address payable fromWallet,
    string memory tokenA,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted validTokens(tokenA, tokenB) returns (uint amountA, uint amountB) {
    // Approve transfer of uniswap LP token back to uniswap
    approve(liquidity, "uniswap-LP", false);
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    deadline = block.timestamp + 15000;
    if (tokenAddresses[tokenA] != tokenAddresses["ETH"]) {
      // Remove two IERC20 tokens from liquidity pool
      (amountA, amountB) = uniswapRouter.removeLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], liquidity, amountAMin, amountBMin, address(this), deadline);
    } else  {
      // Remove one ETH and one IERC20 token from liquidity pool
      (amountA, amountB) = uniswapRouter.removeLiquidityETH(tokenAddresses[tokenB], liquidity, amountBMin, amountAMin, address(this), deadline);
    }
    // return tokens from withdrawing liquidity
    transfer(fromWallet, tokenA, amountA);
    transfer(fromWallet, tokenB, amountB);
    return (amountA, amountB);
  }
}
