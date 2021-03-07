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
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    //TODO: For now we are using Kovan test network pool addresses
    manager = msg.sender;
    updateTokenAddresses('ETH', uniswapRouter.WETH());
    updateTokenAddresses('DAI', 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    updateTokenAddresses('MKR', 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD);
    updateTokenAddresses('UNI-LP', 0xB10cf58E08b94480fCb81d341A63295eBb2062C2);
  }

  modifier restricted() {
      require(msg.sender == manager, "TUNISWAP_MANAGER_ERROR");
      _;
  }

  modifier validTokens(string memory tokenA, string memory tokenB) {
    require(tokenAddresses[tokenA] != tokenAddresses[tokenB], "TUNISWAP_TOKENMATCH_ERROR");
    require(tokenAddresses[tokenA] != address(0x0) && tokenAddresses[tokenB] != address(0x0), "TUNISWAP_TOKENEXIST_ERROR");
    _;
  }

  receive() external payable {}

  fallback() external payable {}

  function updateTokenAddresses(string memory tokenName, address tokenAddress) private restricted {
      tokenAddresses[tokenName] = tokenAddress;
  }

  function approve(uint tradeAmount, address tokenAddress) private restricted {
    IERC20 token = IERC20(tokenAddress);
    uint tokenBalance = token.balanceOf(address(this));
    //TODO: Should we have robustness checks in mainnet?
    require (tradeAmount < tokenBalance, "TUNISWAP_INSUFFICIENT_BALANCE");
    //TODO: Should we have robustness checks in mainnet?
    require(token.approve(address(uniswapRouter), tradeAmount), "TUNISWAP_APPROVAL_ERROR");
  }

  function getTradePath(string memory fromToken, string memory toToken) public validTokens(fromToken, toToken) view returns (address[] memory)  {
    address[] memory path = new address[](2);
    path[0] = tokenAddresses[fromToken];
    path[1] = tokenAddresses[toToken];
    return path;
  }

  function swapTokens(uint tradeAmount, uint minSwapAmount, string memory fromToken, string memory toToken, uint deadline)
  external payable restricted validTokens(fromToken, toToken) returns (bool) {
    address[] memory tradePath = getTradePath(fromToken, toToken);

    //TODO: remove this for mainnet, should be replaced with frontend passed value
    minSwapAmount = 1;
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    deadline = block.timestamp + 15000;

    if (tradePath[0] != tokenAddresses['ETH']) {
      approve(tradeAmount, tradePath[0]);
      if (tradePath[1] != tokenAddresses['ETH']) {
        uniswapRouter.swapExactTokensForTokens(tradeAmount, minSwapAmount, tradePath, address(this), deadline);
      }
      else{
        uniswapRouter.swapExactTokensForETH(tradeAmount, minSwapAmount, tradePath, address(this), deadline);
      }
    } else  {
      uniswapRouter.swapExactETHForTokens{value: tradeAmount}(minSwapAmount, tradePath, address(this), deadline);
    }
    return true;
  }

  function addLiquidity(string memory tokenA, string memory tokenB,
  uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, uint deadline)
  external payable restricted validTokens(tokenA, tokenB) returns (bool) {
    require(tokenAddresses[tokenB] != tokenAddresses['ETH'], "TUNISWAP_TOKENORDER_ERROR");
    approve(amountBDesired, tokenAddresses[tokenB]);

    //TODO: remove this for mainnet, should be replaced with frontend passed value
    deadline = block.timestamp + 15000;

    if (tokenAddresses[tokenA] != tokenAddresses['ETH']) {
      approve(amountADesired, tokenAddresses[tokenA]);
      uniswapRouter.addLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
    } else  {
      uniswapRouter.addLiquidityETH{value: amountADesired}(tokenAddresses[tokenB], amountBDesired, amountBMin, amountAMin, address(this), deadline);
    }
    return true;
  }

  function removeLiquidity(string memory tokenA, string memory tokenB, uint liquidity, uint amountAMin, uint amountBMin, uint deadline)
  external payable restricted validTokens(tokenA, tokenB) returns (bool) {
    require(tokenAddresses[tokenB] != tokenAddresses['ETH'], "TUNISWAP_TOKENORDER_ERROR");
    approve(liquidity, tokenAddresses['UNI-LP']);
    //TODO: remove this for mainnet, should be replaced with frontend passed value
    deadline = block.timestamp + 15000;

    if (tokenAddresses[tokenA] != tokenAddresses['ETH']) {
      uniswapRouter.removeLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], liquidity, amountAMin, amountBMin, address(this), deadline);
    } else  {
      uniswapRouter.removeLiquidityETH(tokenAddresses[tokenB], liquidity, amountBMin, amountAMin, address(this), deadline);
    }
    return true;
  }
}
