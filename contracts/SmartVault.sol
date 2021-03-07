// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// use standard like https://openzeppelin.com/contracts/ to protect reentrant attacks
// to replace mutex paradigm
// TODO: solve gasDebit Chicken and Egg problem. gasleft() gives you gas on msg.
// TODO: use fallback or receive for funds?

// Comments:
// 0. Verify user is owner of a wallet. They don't have the p keys (e.g. coinbase)
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
contract Compound {
    function supplyEthToCompound(address payable _cEtherContract) public payable returns (bool) {}
    function supplyErc20ToCompound(address _erc20Contract, address _cErc20Contract, uint256 _numTokensToSupply) public returns (uint) {}
    function redeemCErc20Tokens(uint256 amount, bool redeemType, address _cErc20Contract) public returns (bool) {}
    function redeemCEth(uint256 amount, bool redeemType, address _cEtherContract) public returns (bool) {}
}

contract SmartVault {
    
    address public manager;
    mapping(address => uint256) public balances;
    uint256 public gasRebate = 0;
    bool lock = false;
    
    // TODO: Do we need events?
    event Deposit(address indexed owner, uint256 tokens);
    event Withdraw(address indexed owner, uint256 tokens);
    
    constructor() {
        manager = msg.sender;
    }
    
    function withdraw(address payable owner, uint256 gasDebit, uint256 amount) noReentrancy requireManager external payable {
        // owner is address to whom we're sending funds
        // gasDebit is user specified gas allowance (must be subtracted from balance)
        // amt is user specified withdrawal amount
        // check that owner has specified amount
        require((balances[owner] >= (amount + gasDebit)), "Insufficient funds.");

        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Failed to send Ether");

        // assume gas is taken. need to solve the rebate problem.
        balances[owner] = balances[owner] - amount - gasDebit;
        emit Withdraw(owner, amount);
        debitGas(gasDebit);
    }

    // design the interfaces to be portable across all borrowing / lending
    // TODO: enum for provider?
    Compound comp;
    function lendETH(address payable owner, uint256 gasDebit, address cvContract, uint256 amount, address payable _cEtherContract) requireManager external payable {
        require((balances[owner] >= (amount + gasDebit)), "Insufficient funds.");
        comp = Compound(cvContract);
        comp.supplyEthToCompound{value:amount}(_cEtherContract);
        balances[owner] = balances[owner] - amount - gasDebit;
        debitGas(gasDebit);
    }

    /***function lendETH(address payable owner, uint256 gasDebit, address cvContract, uint256 amount, address payable _cEtherContract) noReentrancy requireManager external payable {
        require((balances[owner] >= (amount + gasDebit)), "Insufficient funds.");
        Compound comp = Compound(cvContract);
        comp.supplyEthToCompound{value:amount}(_cEtherContract);
        balances[owner] = balances[owner] - amount - gasDebit;
        debitGas(gasDebit);
    }

    function killLendETH(address payable owner, uint256 gasDebit, uint256 amount, bool redeemType, address _cEtherContract) noReentrancy requireManager external {
        debitGas(gasDebit);
    }

    function lendERC20(address payable owner, uint256 gasDebit, uint256 amount, bool redeemType, address _cEtherContract) noReentrancy requireManager external {
        debitGas(gasDebit);
    }

    function killLendERC20(address payable owner, uint256 gasDebit, uint256 amount, bool redeemType, address _cErc20Contract) noReentrancy requireManager external {
        debitGas(gasDebit);
    }***/

    function debitGas(uint256 debit) noReentrancy requireManager internal {
        gasRebate += debit;
    }
    
    receive() noReentrancy payable external {
        // when funds sent, save to balances
        balances[msg.sender] = balances[msg.sender] + msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    modifier noReentrancy() {
        require(!lock, "Reentrant call.");
        lock = true;
        _;
        lock = false;
    }
    
    modifier requireManager() {
        require((msg.sender == manager), "Manager must call SmartVault.");
        _;
    }
}
