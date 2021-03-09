// SPDX-License-Identifier: MIT
pragma solidity >=0.6;

interface ICVContract {
    function deposit(address walletOwner, string memory tokenName, uint amount) external;
}