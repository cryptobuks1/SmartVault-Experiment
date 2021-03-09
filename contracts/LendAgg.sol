// SPDX-License-Identifier: MIT
pragma solidity >=0.6;

import "./interfaces/IERC20.sol";
import "./interfaces/ICERC20.sol";
import "./interfaces/ICETH.sol";

// TODO: add compound address mapping
contract LendAgg {

    address public manager; // contract creator
    mapping(address => mapping(string => uint)) public balances; // user eth / token balances
    //uint public gasRebate = 0; // ETH expenditures from MasterWallet
    // TODO: implement gas rebate tracking

    // reEntrancy lock
    bool lock = false;
    
    constructor() {
        manager = msg.sender;
    }

    // function modifiers
    modifier restricted() {
        require((msg.sender == manager), "LENDAGG_MANAGER_ERROR");
        _;
    }
    
    modifier noReentrancy() {
        require(!lock, "LENDAGG_REENTRANT_ERROR");
        lock = true;
        _;
        lock = false;
    }

    event CompoundLog(string, uint);

    function deposit(
        address walletOwner,
        string memory tokenName,
        uint amount
    ) external noReentrancy {
        balances[walletOwner][tokenName] += amount;
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

    function supplyETHToCompound(
        address walletOwner,
        uint amount,
        address payable CETHContract
    ) public payable noReentrancy returns (bool) {
        require((balances[walletOwner]["ETH"] >= (amount)), "LENDAGG_SUPPLYFUNDS_ERROR");
        // Create a reference to the corresponding cToken contract
        ICETH cETH = ICETH(CETHContract);
        uint prevBalance = cETH.balanceOf(address(this));

        // Amount of current exchange rate from cToken to underlying
        uint exchangeRateMantissa = cETH.exchangeRateCurrent();
        emit CompoundLog("Exchange Rate (scaled up by 1e18): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint supplyRateMantissa = cETH.supplyRatePerBlock();
        emit CompoundLog("Supply Rate: (scaled up by 1e18)", supplyRateMantissa);

        cETH.mint{value : amount}(); // TODO: unfort we don't get the trade data, it's broadcast to bchain via events

        uint currBalance = cETH.balanceOf(address(this));
        subtractBalance(walletOwner, "ETH", amount);
        addBalance(walletOwner, "CETH", currBalance - prevBalance);
        return true;
    }

    function supplyTokenToCompound(
        address walletOwner,
        string memory tokenName,
        string memory cTokenName,
        address tokenContract,
        address cTokenContract,
        uint numTokensToSupply
    ) public noReentrancy returns (uint) {
        require((balances[walletOwner][tokenName] >= (numTokensToSupply)), "LENDAGG_SUPPLYFUNDS_ERROR");
        // Create a reference to the underlying asset contract, like DAI.
        IERC20 underlying = IERC20(tokenContract);

        // Create a reference to the corresponding cToken contract, like cDAI
        ICERC20 cToken = ICERC20(cTokenContract);
        uint prevBalance = cToken.balanceOf(address(this));

        // Amount of current exchange rate from cToken to underlying
        uint exchangeRateMantissa = cToken.exchangeRateCurrent();
        emit CompoundLog("Exchange Rate (scaled up): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint supplyRateMantissa = cToken.supplyRatePerBlock();
        emit CompoundLog("Supply Rate: (scaled up)", supplyRateMantissa);

        // Approve transfer on the ERC20 contract
        underlying.approve(cTokenContract, numTokensToSupply);

        // Mint cTokens
        uint mintResult = cToken.mint(numTokensToSupply);
        uint currBalance = cToken.balanceOf(address(this));
        subtractBalance(walletOwner, tokenName, numTokensToSupply);
        // TODO: is it cheaper to just pass cTokenName in?
        addBalance(walletOwner, cTokenName, currBalance - prevBalance);
        return mintResult;
    }

    function redeemCTokens(
        address walletOwner,
        string memory cTokenName,
        string memory tokenName,
        uint amount,
        address tokenContract,
        address cTokenContract
    ) public noReentrancy returns (bool) {
        require((balances[walletOwner][cTokenName] >= (amount)), "LENDAGG_REDEEMFUNDS_ERROR");
        // Create a reference to the corresponding cToken contract, like cDAI
        ICERC20 cToken = ICERC20(cTokenContract);

        IERC20 underlying = IERC20(tokenContract);
        uint prevBalance = underlying.balanceOf(address(this));
        // `amount` is scaled up, see decimal table here:
        // https://compound.finance/docs#protocol-math

        uint redeemResult;
        // TODO: just set equal to true for now
        bool redeemType = true;
        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        // Error codes are listed here:
        // https://compound.finance/developers/ctokens#ctoken-error-codes
        emit CompoundLog("If this is not 0, there was an error", redeemResult);

        uint currBalance = underlying.balanceOf(address(this));
        subtractBalance(walletOwner, cTokenName, amount);
        addBalance(walletOwner, tokenName, currBalance - prevBalance);
        return true;
    }

    function redeemCETH(
        address walletOwner,
        uint amount,
        address CETHContract
    ) public noReentrancy returns (bool) {
        require((balances[walletOwner]["ETH"] >= (amount)), "LENDAGG_REDEEMFUNDS_ERROR");
        // Create a reference to the corresponding cToken contract
        ICETH cETH = ICETH(CETHContract);
        uint prevBalance = address(this).balance;

        // `amount` is scaled up by 1e18 to avoid decimals

        uint redeemResult;
        // TODO: set redeem type to true for now
        bool redeemType = true;
        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cETH.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cETH.redeemUnderlying(amount);
        }

        // Error codes are listed here:
        // https://compound.finance/docs/ctokens#ctoken-error-codes
        emit CompoundLog("If this is not 0, there was an error", redeemResult);
        uint currBalance = address(this).balance;
        subtractBalance(walletOwner, "CETH", amount);
        addBalance(walletOwner, "ETH", currBalance - prevBalance);
        return true;
    }

    // This is needed to receive ETH when calling `redeemICETH`
    receive() external payable {}
}
