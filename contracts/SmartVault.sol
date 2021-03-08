// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// use standard like https://openzeppelin.com/contracts/ to protect reentrant attacks
// to replace mutex paradigm
// TODO: solve gasDebit Chicken and Egg problem. gasleft() gives you gas on msg.
// TODO: use fallback or receive for funds?

// Comments:
// 0. Verify user is owner of a wallet. They don"t have the p keys (e.g. coinbase)
// so user can guess a wallet or enter a random one hoping to gain access to it.
// websites deposit 2 amts of money for verifying bank accounts. we can do same on wallets
// now wallet is verified.
// 1. we giver user address of SmartVault
// 2. they specify amt of funds.
// 3. within n minutes, they send funds over to smart contract.

// MasterWallet
// Will likely need to be seeded with ether but will be reimbursed by smart contract
// reimbursing each time withdrawal is called is bad idea
// we can store the value in a gasReimburse variable
// but how do we access gas costs?

// TODO: for now import, but is there a delegate pattern so i can point to an address?
// then I can update the address with a new contract for feature updates

// will this flow work for aave as well?
// Compound interface

//import "interfaces/IDEXAgg.sol";
//imoprt "interfaces/IERC20.sol"
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IERC20.sol";
//import "https://github.com/bobnewo/ChainVault/blob/main/contracts/interfaces/IDEXAgg.sol";
pragma solidity ^0.8.0;

interface IDEXAgg {
  function getAddress() external view returns (address contractAddress);
  function swapTokenForToken(
    string memory exchange,
    address fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    address toToken,
    uint deadline
  ) external payable returns (uint[] memory amounts);
  function swapTokenforETH(
    string memory exchange,
    address payable fromWallet,
    uint tradeAmount,
    uint minSwapAmount,
    address fromToken,
    uint deadline
  ) external payable returns (uint[] memory amounts);
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
  ) external payable returns (uint amountA, uint amountB, uint liquidity);
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
  ) external payable returns (uint amountA, uint amountB);
  function removeLiquidityETH(
    string memory exchange,
    address payable fromWallet,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable returns (uint amountA, uint amountB);
}

contract TCompound {
    function supplyEthToCompound(address payable _cEtherContract) public payable returns (bool) {}
    function supplyErc20ToCompound(address _erc20Contract, address _cErc20Contract, uint _numTokensToSupply) public returns (uint) {}
    function redeemCErc20Tokens(uint amount, bool redeemType, address _cErc20Contract) public returns (bool) {}
    function redeemCEth(uint amount, bool redeemType, address _cEtherContract) public returns (bool) {}
}

contract SmartVault {

  address public manager;
  mapping(address => mapping(string => uint)) public balances;

  mapping(string => address) public tokenAddresses;
  uint public gasRebate = 0;
  bool lock = false;

  IDEXAgg dexAgg;
  TCompound compoundInterface;

  constructor() {
    manager = msg.sender;
    // TODO: ERASE BELOW FOR MAINNET LAUNCH
    updateTokenAddresses("ETH", address(0x0));
    updateTokenAddresses("DAI", 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    updateTokenAddresses("MKR", 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD);
    // uniswap lp token
    updateTokenAddresses("uniswap", 0xB10cf58E08b94480fCb81d341A63295eBb2062C2);
  }

  modifier restricted() {
    require((msg.sender == manager), "SMARTVAULT_MANAGER_ERROR");
    _;
  }

  modifier noReentrancy() {
    require(!lock, "SMARTVAULT_REENTRANT_ERROR");
    lock = true;
    _;
    lock = false;
  }

  // introducing add/subtractBalance to reduce stack depth in func calls
  // TODO: is my understanding correct?, or is this stupid?
  function addBalance(
    address walletOwner,
    string memory token,
    uint amount
  ) private restricted {
    balances[walletOwner][token] = balances[walletOwner][token] + amount;
  }

  function subtractBalance(
    address walletOwner,
    string memory token,
    uint amount
  ) private restricted {
    balances[walletOwner][token] = balances[walletOwner][token] - amount;
  }

  function debitGas(address walletOwner, uint gasAmount) internal noReentrancy restricted  {
    // Charge user gas for transaction, rebate after if remainder exists
    balances[walletOwner]["ETH"] = balances[walletOwner]["ETH"]  - gasAmount;
    gasRebate += gasAmount;
  }

  function updateTokenAddresses(
    string memory tokenName,
    address tokenAddress
  ) public restricted {
    // TODO: MAKE IMMUTABLE FOR CONTRACT SECURITY
    // TODO: WE PROBABLY ONLY NEED THIS IN SMART VAULT CONTRACT, CAN THEN PASS ADDRESSES TO OTHER CONTRACTS GIVEN THINGS ARE SECURE HERE
    tokenAddresses[tokenName] = tokenAddress;
  }

  function deposit() external noReentrancy payable {
    // Add incoming funds to balance dictionary
    balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] + msg.value;
  }

  function depositToken() external noReentrancy payable {
    // TODO: include ERC20 deposit functions for MetaMask users
  }

  receive() noReentrancy payable external {
    // Add incoming funds to balance dictionary
    balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] + msg.value;
  }

  function approveToken(
    address transferAddress,
    uint transferAmount,
    string memory tokenName,
    bool transferFunds
  ) private restricted {
    // initialize IERC20 token according to provided address
    IERC20 token = IERC20(tokenAddresses[tokenName]);
    // get ERC20 token balance on contract
    uint tokenBalance = token.balanceOf(address(this));
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET (?)
    require (transferAmount < tokenBalance, "SMARTVAULT_APPROVEFUNDS_ERROR");
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET (?)
    require(token.approve(transferAddress, transferAmount), "SMARTVAULT_APPROVE_ERROR");
    if (transferFunds){
      require(token.transfer(transferAddress, transferAmount), "SMARTVAULT_ERC20TRANSFER_ERROR");
    }
  }

  function transferETH(
    address payable fromWallet,
    uint transferAmount
  ) private restricted {
      require(address(this).balance >= transferAmount, "SMARTVAULT_ETHTRANSFER_ERROR");
      fromWallet.transfer(transferAmount);
  }

  function updateDEXAgg(address newDexAggAddress) public restricted {
    // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY
    dexAgg = IDEXAgg(newDexAggAddress);
  }

  function updateTCompound(address newTCompoundAddress) public restricted {
    // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY
    compoundInterface = TCompound(newTCompoundAddress);
  }

  function withdrawToken(
    address payable walletOwner,
    string memory fromToken,
    uint debitAmount,
    uint gasAmount
    ) public noReentrancy {
    require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    require((balances[walletOwner][fromToken] >= (debitAmount)), "SMARTVAULT_WITHDRAWFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    //TODO : implement ERC20 withdrawal
    bool sent = true;
    require(sent, "SMARTVAULT_ERC20SENT_ERROR");
    subtractBalance(walletOwner, fromToken, debitAmount);
  }

  function withdrawETH(
    address payable walletOwner,
    uint debitAmount,
    uint gasAmount
    ) public noReentrancy {
      // if ETH transaction send balanceDebit directly
    require((balances[walletOwner]["ETH"] >= (debitAmount+gasAmount)), "SMARTVAULT_WITHDRAWFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    (bool sent, ) = walletOwner.call{value: debitAmount}("");
    require(sent, "SMARTVAULT_ETHSENT_ERROR");
    subtractBalance(walletOwner, "ETH", debitAmount);
  }

  function swapETHforToken(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    uint tradeAmount,
    uint minSwapAmount,
    string memory toToken,
    uint deadline
  ) external payable noReentrancy restricted {
    require((balances[walletOwner]["ETH"] >= (gasAmount+tradeAmount)), "SMARTVAULT_SWAPFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    // TODO: How to best route funds to and from DEXAgg contract?
    uint[] memory swapAmounts = dexAgg.swapETHforToken(exchange, payable(this), tradeAmount, minSwapAmount, tokenAddresses[toToken], deadline);
    // After successful swap we allocate new funds
    subtractBalance(walletOwner, "ETH", swapAmounts[0]);
    addBalance(walletOwner, toToken, swapAmounts[1]);
  }

  function swapTokenForToken(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    string memory toToken,
    uint deadline
  ) external payable noReentrancy restricted {
    require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    require((balances[walletOwner][fromToken] >= (tradeAmount)), "SMARTVAULT_SWAPFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    // TODO: How to route funds to DEXAgg contract?
    uint[] memory swapAmounts = dexAgg.swapTokenForToken(exchange, payable(this), tradeAmount, minSwapAmount,
    tokenAddresses[fromToken], tokenAddresses[toToken],  deadline);
    // After successful swap we allocate new funds
    subtractBalance(walletOwner, fromToken, swapAmounts[0]);
    addBalance(walletOwner, toToken, swapAmounts[1]);
  }

  function swapTokenforETH(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    uint deadline
  ) external payable noReentrancy restricted {
    require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    require((balances[walletOwner][fromToken] >= (tradeAmount)), "SMARTVAULT_SWAPFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    // TODO: How to best route funds to and from DEXAgg contract?
    uint[] memory swapAmounts = dexAgg.swapTokenforETH(exchange, payable(this), tradeAmount, minSwapAmount, tokenAddresses[fromToken], deadline);
    // After successful swap we allocate new funds
    subtractBalance(walletOwner, fromToken, swapAmounts[0]);
    addBalance(walletOwner, fromToken, swapAmounts[1]);
  }

  function addLiquidityETH(
    address payable walletOwner,
    string memory exchange,
    uint gasAmount,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable noReentrancy restricted {
    // Require ETH to be tokenA if passed as argument
    require((balances[walletOwner]["ETH"] >= (amountADesired+gasAmount)), "SMARTVAULT_SWAPFUNDS_ERROR");
    require((balances[walletOwner][tokenB] >= (amountBDesired)), "SMARTVAULT_SWAPFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    // TODO: How to route funds to and from DEXAgg contract?
    (uint amountA, uint amountB, uint liquidity) = dexAgg.addLiquidityETH(exchange, payable(this), tokenAddresses[tokenB],
    amountADesired, amountBDesired, amountAMin, amountBMin, deadline);
    subtractBalance(walletOwner, "ETH", amountA);
    subtractBalance(walletOwner, tokenB, amountB);
    addBalance(walletOwner, string(abi.encodePacked(exchange,"-","ETH")), amountA);
    addBalance(walletOwner, string(abi.encodePacked(exchange,"-",tokenB)), amountB);
    addBalance(walletOwner, exchange, liquidity);
  }

  function addLiquidityTokens(
    address payable walletOwner,
    string memory exchange,
    uint gasAmount,
    string memory tokenA,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable noReentrancy restricted {
    // Require ETH to be tokenA if passed as argument
    require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    require((balances[walletOwner][tokenA] >= (amountADesired)), "SMARTVAULT_SWAPFUNDS_ERROR");
    require((balances[walletOwner][tokenB] >= (amountBDesired)), "SMARTVAULT_SWAPFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    // TODO : Support more exchanges
    // TODO: Route funds to  uniswap contract?
    (uint amountA, uint amountB, uint liquidity) = dexAgg.addLiquidityTokens(exchange, payable(this), tokenAddresses[tokenA], tokenAddresses[tokenB],
    amountADesired, amountBDesired, amountAMin, amountBMin, deadline);
    // Update exchange LP tokens corresponding to this account
    subtractBalance(walletOwner, tokenA, amountA);
    subtractBalance(walletOwner, tokenB, amountB);
    addBalance(walletOwner, string(abi.encodePacked(exchange,"-",tokenA)), amountA);
    addBalance(walletOwner, string(abi.encodePacked(exchange,"-",tokenB)), amountB);
    addBalance(walletOwner, exchange, liquidity);
  }

  function removeLiquidityETH(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable noReentrancy restricted {
    require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    require((balances[walletOwner][exchange] >= (liquidity)), "SMARTVAULT_LIQFUNDS_ERROR");
    string memory lptokenA = string(abi.encodePacked(exchange,"-","ETH"));
    string memory lptokenB = string(abi.encodePacked(exchange,"-",tokenB));
    require((balances[walletOwner][lptokenA] >= (amountAMin)), "SMARTVAULT_LIQFUNDS_ERROR");
    require((balances[walletOwner][lptokenB] >= (amountBMin)), "SMARTVAULT_LIQFUNDS_ERROR");
    // TODO: user specific check for liquidity being withdrawn
    debitGas(walletOwner, gasAmount);
    // TODO: How to route funds to an from uniswap contract?
    (uint amountA, uint amountB) = dexAgg.removeLiquidityETH(exchange, payable(this), tokenAddresses[tokenB],
    liquidity, amountAMin, amountBMin, deadline);
    // Return staked funds to wallet
    subtractBalance(walletOwner, exchange, liquidity);
    subtractBalance(walletOwner, lptokenA, amountA);
    subtractBalance(walletOwner, lptokenB, amountB);
    addBalance(walletOwner, "ETH", amountA);
    addBalance(walletOwner, tokenB, amountB);
  }

  function removeLiquidityTokens(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    string memory tokenA,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable noReentrancy restricted {
    require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    require((balances[walletOwner][exchange] >= (liquidity)), "SMARTVAULT_LIQFUNDS_ERROR");
    string memory lptokenA = string(abi.encodePacked(exchange,"-",tokenA));
    string memory lptokenB = string(abi.encodePacked(exchange,"-",tokenB));
    require((balances[walletOwner][lptokenA] >= (amountAMin)), "SMARTVAULT_LIQFUNDS_ERROR");
    require((balances[walletOwner][lptokenB] >= (amountBMin)), "SMARTVAULT_LIQFUNDS_ERROR");
    // TODO: user specific check for liquidity being withdrawn
    debitGas(walletOwner, gasAmount);
      // TODO: How to route funds to an from uniswap contract?
    (uint amountA, uint amountB) = dexAgg.removeLiquidityTokens(exchange, payable(this), tokenAddresses[tokenA], tokenAddresses[tokenB],
    liquidity, amountAMin, amountBMin, deadline);
    // Return staked funds to wallet
    subtractBalance(walletOwner, exchange, liquidity);
    subtractBalance(walletOwner, lptokenA, amountA);
    subtractBalance(walletOwner, lptokenB, amountB);
    addBalance(walletOwner, tokenA, amountA);
    addBalance(walletOwner, tokenB, amountB);
  }

  function lendETH(
    address walletOwner,
    uint gasAmount,
    uint tradeAmount,
    address payable _cEtherContract
  ) external payable noReentrancy restricted {
    require((balances[walletOwner]["ETH"] >= (tradeAmount+gasAmount)), "SMARTVAULT_LENDFUNDS_ERROR");
    debitGas(walletOwner, gasAmount);
    // TODO: remove passed contract to be hard coded in immutable way into compoound, as per uniswap implementation
    compoundInterface.supplyEthToCompound{value:tradeAmount}(_cEtherContract);
    subtractBalance(walletOwner, "ETH", tradeAmount);
    // TODO : Add support for ERC20 lending, etc..
  }



    /***function lendETH(address payable owner, uint gasDebit, address cvContract, uint amount, address payable _cEtherContract) noReentrancy restricted external payable {
        require((balances[owner] >= (amount + gasDebit)), "Insufficient funds.");
        Compound comp = Compound(cvContract);
        comp.supplyEthToCompound{value:amount}(_cEtherContract);
        balances[owner] = balances[owner] - amount - gasDebit;
        debitGas(gasDebit);
    }

    function killLendETH(address payable owner, uint gasDebit, uint amount, bool redeemType, address _cEtherContract) noReentrancy restricted external {
        debitGas(gasDebit);
    }

    function lendERC20(address payable owner, uint gasDebit, uint amount, bool redeemType, address _cEtherContract) noReentrancy restricted external {
        debitGas(gasDebit);
    }

    function killLendERC20(address payable owner, uint gasDebit, uint amount, bool redeemType, address _cErc20Contract) noReentrancy restricted external {
        debitGas(gasDebit);
    }***/



}
