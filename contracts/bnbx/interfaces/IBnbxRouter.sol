// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;
// TODO:Manoj need to remove methods from this file

interface IBnbxRouter {
    /**
     * Events
     */

    event Deposit(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    event Claim(
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    event Withdrawal(
        address indexed owner,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    event ChangeVault(address vault);

    event ChangeStakeManager(address stakeManager);

    event ChangeCeToken(address ceToken);

    event ChangeBnbxToken(address bnbxToken);

    event ChangeProvider(address provider);

    /**
     * Methods
     */

    /**
     * Deposit
     */

    // in BNB
    function deposit() external payable returns (uint256);

    // in aBNBc
    function depositBnbxFrom(address owner, uint256 amount)
    external
    returns (uint256);

    function depositBnbx(uint256 amount) external returns (uint256);

    /**
     * Claim
     */

    // claim in BNBx
    function claim(address recipient) external returns (uint256);

    /**
     * Withdrawal
     */

    // BNB
    function withdraw(address recipient, uint256 amount)
    external
    returns (uint256);


    // BNBx
    function withdrawBnbx(address recipient, uint256 amount)
    external
    returns (uint256);

    function getYieldFor(address account) external view returns(uint256);
}