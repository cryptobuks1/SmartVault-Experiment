pragma solidity ^0.8.0;

interface IDEXAgg {
  function getAddress() external view returns (address payable contractAddress);
  function swapTokenForToken(
    string memory exchange,
    address fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    address toToken,
    uint deadline
  ) external returns (uint[] memory amounts);
  function swapTokenforETH(
    string memory exchange,
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    uint deadline
  ) external returns (uint[] memory amounts);
  function swapETHforToken(
    string memory exchange,
    address fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address toToken,
    uint deadline
  ) external payable returns (uint[] memory amounts);
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
  ) external returns (uint amountA, uint amountB, uint liquidity);
  function addLiquidityETH(
    string memory exchange,
    address fromWallet,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable returns (uint amountA, uint amountB, uint liquidity);
  function removeLiquidityTokens(
    string memory exchange,
    address fromWallet,
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external returns (uint amountA, uint amountB);
  function removeLiquidityETH(
    string memory exchange,
    address payable fromWallet,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external returns (uint amountA, uint amountB);
}
