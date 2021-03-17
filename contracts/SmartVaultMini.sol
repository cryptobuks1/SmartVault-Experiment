 // SPDX-License-Identifier: MIT
pragma solidity >=0.6;
// TODO: currently at >=0.6 to support older services

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

// generic interfaces
import "./interfaces/IERC20.sol";

// CV contract interfaces
import "./interfaces/ICVContract.sol";

contract SmartVault {

    address public manager; // contract creator
    mapping(address => mapping(string => uint)) public balances; // user eth / token balances
    uint public gasRebate = 0; // ETH expenditures from MasterWallet
    
    // reEntrancy lock
    bool lock = false;

    //Generic interface for all CV Contracts
    ICVContract cvContract;
    
    constructor() {
        manager = msg.sender;
    }
    
    // function modifiers
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
    
    // functions to edit user balances.
    function addBalance(
        address walletOwner,
        string memory token,
        uint amount
    ) public restricted {
        balances[walletOwner][token] = balances[walletOwner][token] + amount;
    }
    
    function subtractBalance(
        address walletOwner,
        string memory token,
        uint amount
    ) public restricted {
        balances[walletOwner][token] = balances[walletOwner][token] - amount;
    }
    
    function debitGas(address walletOwner, uint gasAmount) internal restricted  {
        // Charge user gas for transaction, rebate after if remainder exists
        subtractBalance(walletOwner, "ETH", gasAmount);
        gasRebate += gasAmount;
    }
    
    receive() noReentrancy payable external {
        // Add incoming funds to balance dictionary
        addBalance(msg.sender, "ETH", msg.value);
    }
    
    function approveToken(
        address transferAddress,
        uint transferAmount,
        address tokenAddress,
        bool transferFunds
    ) private restricted returns (bool) {
        // initialize IERC20 token according to provided address
        IERC20 token = IERC20(tokenAddress);
        // get ERC20 token balance on contract
        uint tokenBalance = token.balanceOf(address(this));
        // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS HERE IN MAINNET (?)
        require (transferAmount < tokenBalance, "SMARTVAULT_APPROVEFUNDS_ERROR");
        // TODO: SHOULD WE HAVE ROBUSTNESS CHECKS HERE IN MAINNET (?)
        require(token.approve(transferAddress, transferAmount), "SMARTVAULT_APPROVE_ERROR");

        if (transferFunds){
            require(token.transfer(transferAddress, transferAmount), "SMARTVAULT_ERC20TRANSFER_ERROR");
        }
        return true;
    }
    
    // for withdrawals/transfers of ETH / ERC-20 to addresses
    function transferToken(
        address walletOwner,
        address recipient,
        string memory tokenName,
        address tokenAddress,
        uint debitAmount,
        uint gasAmount
    ) public restricted {
        require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
        require((balances[walletOwner][tokenName] >= (debitAmount)), "SMARTVAULT_TRANSFERFUNDS_ERROR");
        debitGas(walletOwner, gasAmount);
        require(approveToken(recipient, debitAmount, tokenAddress, true), "SMARTVAULT_ERC20SENT_ERROR");
        subtractBalance(walletOwner, tokenName, debitAmount);
    }
    
    function transferETH(
        address walletOwner,
        address payable recipient,
        uint debitAmount,
        uint gasAmount
    ) public restricted {
        // if ETH transaction send balanceDebit directly
        require((balances[walletOwner]["ETH"] >= (gasAmount)), "SMARTVAULT_GASFUNDS_ERROR");
        require((balances[walletOwner]["ETH"] >= (debitAmount)), "SMARTVAULT_TRANSFERFUNDS_ERROR");
        debitGas(walletOwner, gasAmount);
        (bool sent, ) = recipient.call{value: debitAmount}("");
        require(sent, "SMARTVAULT_ETHSENT_ERROR");
        subtractBalance(walletOwner, "ETH", debitAmount);
    }

    function transferTokenToContract(
        address walletOwner,
        address contractAddress,
        string memory tokenName,
        address tokenAddress,
        uint debitAmount,
        uint gasAmount
    ) public restricted {
        transferToken(walletOwner, contractAddress, tokenName, tokenAddress, debitAmount, gasAmount);
        cvContract = ICVContract(contractAddress);
        cvContract.addBalance(walletOwner, tokenName, debitAmount);
    }

    function transferETHToContract(
        address walletOwner,
        address payable contractAddress,
        uint debitAmount,
        uint gasAmount
    ) public restricted {
        transferETH(walletOwner, contractAddress, debitAmount, gasAmount);
        cvContract = ICVContract(contractAddress);
        cvContract.addBalance(walletOwner, "ETH", debitAmount);
    }

}