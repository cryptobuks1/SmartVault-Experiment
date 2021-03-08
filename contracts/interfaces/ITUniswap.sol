pragma solidity ^0.8.0;

//import "interfaces/IUniswapV2Router02.sol";
//imoprt "interfaces/IERC20.sol"
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IERC20.sol";

interface ITUniswap {
  function getAddress() external view returns (address contractAddress);
  function updateUniswapRouter(
    address tokenAddress
  ) external;
  function updateTokenAddresses(
    string memory tokenName,
    address tokenAddress
  ) public;
  function approve(
    uint transferAmount,
    string memory tokenName,
    bool transferFunds
  ) private;
  function transfer(
    address payable fromWallet,
    string memory tokenName,
    uint transferAmount
  ) private;
  function getTradePath(
    string memory fromToken,
    string memory toToken
  ) private view returns (address[] memory);
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
