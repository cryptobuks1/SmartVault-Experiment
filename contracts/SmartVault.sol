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
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IERC20.sol";
import "https://github.com/bobnewo/ChainVault/blob/main/contracts/interfaces/ITUniswapTest2.sol";
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

  ITUniswap uniswapInterface;
  TCompound compoundInterface;

  constructor() {
    manager = msg.sender;
    // TODO: ERASE BELOW FOR MAINNET LAUNCH
    updateTokenAddresses("ETH", address(0x0));
    updateTokenAddresses("DAI", 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    updateTokenAddresses("MKR", 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD);
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
  function addBalance(
    address walletOwner,
    string memory token,
    uint amount
  ) private restricted{
    balances[walletOwner][token] = balances[walletOwner][token] + amount;
  }

  function subtractBalance(
    address walletOwner,
    string memory token,
    uint amount
  ) private restricted{
    balances[walletOwner][token] = balances[walletOwner][token] - amount;
  }

  modifier validSingleToken(
    address walletOwner,
    string memory fromToken,
    uint debitAmount,
    uint gasAmount)
  {
    // If ETH transaction, require wallet hold tradeAmount + gas
    if (tokenAddresses[fromToken] == tokenAddresses["ETH"]) {
      require((balances[walletOwner][fromToken] >= (debitAmount+gasAmount)), "SMARTVAULT_TRADEFUNDS_ERROR");
    }
    else{
      // If ERC20 transaction, require wallet hold tradeAmount of IERC20 and gasAmount of ETH
      require((balances[walletOwner][fromToken] >= (debitAmount)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    }
    debitGas(walletOwner, gasAmount);
    subtractBalance(walletOwner, fromToken, debitAmount);
    _;
  }

  modifier validDoubleToken(
    address payable walletOwner,
    string memory tokenA,
    string memory tokenB,
    uint debitA,
    uint debitB,
    uint gasAmount)
    {
    // If ETH transaction, require wallet hold tradeAmount + gas
    if (tokenAddresses[tokenA] == tokenAddresses["ETH"]) {
      require((balances[walletOwner][tokenA] >= (debitA+gasAmount)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner][tokenB] >= (debitB)), "SMARTVAULT_TRADEFUNDS_ERROR");
    }
    else{
      // If ERC20 transaction, require wallet hold tradeAmount of IERC20 and gasAmount of ETH
      require((balances[walletOwner][tokenA] >= (debitA)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner][tokenB] >= (debitB)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    }
    debitGas(walletOwner, gasAmount);
    subtractBalance(walletOwner, tokenA, debitA);
    subtractBalance(walletOwner, tokenB, debitB);
    _;
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
    // TODO: include ERC20 deposit functions for MetaMask users
  }

  receive() noReentrancy payable external {
    // Add incoming funds to balance dictionary
    balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] + msg.value;
  }

  function approve(
    address transferAddress,
    uint transferAmount,
    string memory tokenName,
    bool transferFunds
  ) private restricted {
    // initialize IERC20 token according to provided address
    IERC20 token = IERC20(tokenAddresses[tokenName]);
    // get ERC20 token balance on contract
    uint tokenBalance = token.balanceOf(address(this));
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET
    require (transferAmount < tokenBalance, "SMARTVAULT_INSUFFICIENT_BALANCE");
    // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS IN MAINNET
    require(token.approve(transferAddress, transferAmount), "SMARTVAULT_ERC20APPROVAL_ERROR");
    if (transferFunds){
      require(token.transfer(transferAddress, transferAmount), "SMARTVAULT_ERC20TRANSFER_ERROR");
    }
  }

  function transfer(
    address payable fromWallet,
    string memory tokenName,
    uint transferAmount
  ) private restricted {
    if (tokenAddresses[tokenName] == tokenAddresses["ETH"]) {
      // Do directly if transfer is ETH
      require(address(this).balance >= transferAmount, "SMARTVAULT_ETHTRANSFER_ERROR");
      fromWallet.transfer(transferAmount);
    } else{
      // Do ERC20 approve w/ transfer=True
      approve(fromWallet, transferAmount, tokenName, true);
    }
  }

  function debitGas(address walletOwner, uint gasAmount) internal noReentrancy restricted  {
    // Charge user gas for transaction, rebate after if remainder exists
    balances[walletOwner]["ETH"] = balances[walletOwner]["ETH"]  - gasAmount;
    gasRebate += gasAmount;
  }

  function updateTUniswap(address newTUniswapAddress) public restricted {
    // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY
    uniswapInterface = ITUniswap(newTUniswapAddress);
  }

  function updateTCompound(address newTCompoundAddress) public restricted {
    // TODO: INCLUDE TIME DELAY FOR CONTRACT SECURITY
    compoundInterface = TCompound(newTCompoundAddress);
  }

  function withdraw(
    address payable walletOwner,
    string memory fromToken,
    uint debitAmount,
    uint gasAmount
    ) public noReentrancy validSingleToken(walletOwner, fromToken, debitAmount, gasAmount) {
    if (tokenAddresses[fromToken] == tokenAddresses["ETH"]) {
      // if ETH transaction send balanceDebit directly
      (bool sent, ) = walletOwner.call{value: debitAmount}("");
      require(sent, "Failed to send Ether");
    }
    else {
      //TODO : implement ERC20 withdrawal
      bool sent = true;
      require(sent, "Failed to send Ether");
    }
  }

  function swap(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    string memory toToken,
    uint deadline
  ) external payable noReentrancy restricted validSingleToken(walletOwner, fromToken, tradeAmount, gasAmount) {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      // TODO: How to route funds to and from uniswap contract?
      uint[] memory swapAmounts = uniswapInterface.swapTokens(payable(this), tradeAmount, minSwapAmount,
      tokenAddresses[fromToken], tokenAddresses[toToken],  deadline);
      addBalance(walletOwner, toToken, swapAmounts[1]);
  }
    // After successful swap we allocate new funds
  }

  function addLiquidity(
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
  ) external payable noReentrancy restricted { //validDoubleToken(walletOwner, tokenA, tokenB, amountADesired, amountBDesired, gasAmount) {
    // TODO: Why does using validDoubleToken modifier cause stack depth error? -- it's fine, use code below
    if (tokenAddresses[tokenA] == tokenAddresses["ETH"]) {
      require((balances[walletOwner][tokenA] >= (amountADesired+gasAmount)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner][tokenB] >= (amountBDesired)), "SMARTVAULT_TRADEFUNDS_ERROR");
    }
    else{
      // If ERC20 transaction, require wallet hold tradeAmount of IERC20 and gasAmount of ETH
      require((balances[walletOwner][tokenA] >= (amountADesired)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner][tokenB] >= (amountBDesired)), "SMARTVAULT_TRADEFUNDS_ERROR");
      require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
    }
    debitGas(walletOwner, gasAmount);
    // Require ETH to be tokenA if passed as argument
    require(tokenAddresses[tokenB] != tokenAddresses["ETH"], "SMARTVAULT_TOKENORDER_ERROR");
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      // TODO: How to route funds to and from uniswap contract?
      (uint amountA, uint amountB, uint liquidity) = uniswapInterface.addLiquidity(payable(this), tokenAddresses[tokenA], tokenAddresses[tokenB],
      amountADesired, amountBDesired, amountAMin, amountBMin, deadline);
      // Update UNI-LP tokens corresponding to this account
      subtractBalance(walletOwner, tokenA, amountA);
      subtractBalance(walletOwner, tokenB, amountB);
      addBalance(walletOwner, exchange, liquidity);
    }
  }

  function removeLiquidity(
    address walletOwner,
    string memory exchange,
    uint gasAmount,
    string memory tokenA,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable noReentrancy restricted validSingleToken(walletOwner, exchange, liquidity, gasAmount) {
    // Require ETH to be tokenA if passed as argument
    require(tokenAddresses[tokenB] != tokenAddresses["ETH"], "SMARTVAULT_TOKENORDER_ERROR");
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      // TODO: How to route funds to an from uniswap contract?
      (uint amountA, uint amountB) = uniswapInterface.removeLiquidity(payable(this), tokenAddresses[tokenA], tokenAddresses[tokenB],
      liquidity, amountAMin, amountBMin, deadline);
      // Return staked funds to wallet
      addBalance(walletOwner, tokenA, amountA);
      addBalance(walletOwner, tokenB, amountB);
      subtractBalance(walletOwner, exchange, liquidity);
    }
  }

  function lend(
    address walletOwner,
    uint gasAmount,
    address cvContract,
    uint tradeAmount,
    address payable _cEtherContract
  ) external payable noReentrancy restricted validSingleToken(walletOwner, "ETH", tradeAmount, gasAmount) {
    // TODO: remove passed contract to be hard coded in immutable way into compoound, as per uniswap implementation
    compoundInterface.supplyEthToCompound{value:tradeAmount}(_cEtherContract);
    subtractBalance(walletOwner, "ETH", tradeAmount+gasAmount);
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
