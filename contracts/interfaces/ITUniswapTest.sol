pragma solidity ^0.8.0;

interface ITUniswap {
  function getAddress() external view returns (address contractAddress);
  function updateUniswapRouter(
    address tokenAddress
  ) external;
  function swapTokens(
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    string memory toToken,
    uint deadline
  ) external payable returns (uint[] memory amounts);
  function addLiquidity(
    address payable fromWallet,
    string memory tokenA,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable returns (uint amountA, uint amountB, uint liquidity);
  function removeLiquidity(
    address payable fromWallet,
    string memory tokenA,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable returns (uint amountA, uint amountB);
}
