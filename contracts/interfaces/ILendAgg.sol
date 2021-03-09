// SPDX-License-Identifier: MIT
pragma solidity >=0.6;

interface ILendAgg {
    function supplyETHToCompound(address walletOwner, uint amount, address payable cETHContract) external payable returns (bool);
    function supplyTokenToCompound(address walletOwner, string memory tokenName, address tokenContract, address cTokenContract, uint numTokensToSupply) external returns (uint);
    function redeemCTokens(address walletOwner, string memory cTokenName, uint amount, address cTokenContract) external returns (bool);
    function redeemCETH(address walletOwner, uint amount, address CETHContract) external returns (bool);
}