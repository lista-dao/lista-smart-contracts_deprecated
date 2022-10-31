// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../ceros/interfaces/IVault.sol";
import "./interfaces/IBnbxRouter.sol";
import "./interfaces/IStakeManager.sol";
import "./interfaces/IBnbxToken.sol";

contract BnbxRouter is
IBnbxRouter,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    IVault private _vault;
    IStakeManager private _stakeManager; // default (StakeManager)

    // Tokens
    IBnbxToken private _bnbxToken; // (default BNBx)
    address private _wBnbAddress;
    IERC20Upgradeable private _ceToken; // (default ceBNBx)
    address private _provider;
    /**
     * Modifiers
     */
    modifier onlyProvider() {
        require(
            msg.sender == owner() || msg.sender == _provider,
            "Provider: not allowed"
        );
        _;
    }
    function initialize(
        address bnbxToken,
        address wBnbToken,
        address ceToken,
        address bondToken,
        address vault,
        address stakeManager
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _bnbxToken = IBnbxToken(bnbxToken);
        _wBnbAddress = wBnbToken;
        _ceToken = IERC20Upgradeable(ceToken);
        _vault = IVault(vault);
        _stakeManager = IStakeManager(stakeManager);
        IERC20Upgradeable(bnbxToken).approve(bondToken, type(uint256).max);
        IERC20Upgradeable(bnbxToken).approve(stakeManager, type(uint256).max);
        IERC20Upgradeable(bnbxToken).approve(vault, type(uint256).max);
    }
    /**
     * DEPOSIT
     */
    function deposit()
    external
    payable
    override
    nonReentrant
    returns (uint256 value)
    {
        uint256 amount = msg.value;
        uint256 bnbxAmount = _stakeManager.convertBnbToBnbX(amount);
        _stakeManager.deposit{value: amount}();
       
        // let's check balance of BnbxRouter in BNBx
        require(
            _bnbxToken.balanceOf(address(this)) >= bnbxAmount,
            "insufficient amount of bnbx token in BnbxRouter"
        );
        value = _vault.depositFor(msg.sender, bnbxAmount);
        emit Deposit(msg.sender, _wBnbAddress, bnbxAmount);
        return value;
    }
    function depositBnbxFrom(address owner, uint256 amount)
    external
    override
    onlyProvider
    nonReentrant
    returns (uint256 value)
    {
        _bnbxToken.transferFrom(owner, address(this), amount);
        value = _vault.depositFor(msg.sender, amount);
        emit Deposit(msg.sender, address(_bnbxToken), amount);
        return value;
    }
    function depositBnbx(uint256 amount)
    external
    override
    nonReentrant
    returns (uint256 value)
    {
        _bnbxToken.transferFrom(msg.sender, address(this), amount);
        value = _vault.depositFor(msg.sender, amount);
        emit Deposit(msg.sender, address(_bnbxToken), amount);
        return value;
    }
    /**
     * CLAIM
     */
    // claim yields in BNBx
    function claim(address recipient)
    external
    override
    nonReentrant
    returns (uint256 yields)
    {
        yields = _vault.claimYieldsFor(msg.sender, recipient);
        emit Claim(recipient, address(_bnbxToken), yields);
        return yields;
    }

    /**
     * WITHDRAWAL
     */
    // withdrawal in BNB via staking pool
    /// @param recipient address to receive withdrawan BNB
    /// @param amount in BNB to withdraw from vault
    function withdraw(address recipient, uint256 amount)
    external
    override
    nonReentrant
    returns (uint256 bnbxAmount)
    {
        require(amount > 0, "invalid amount");
        bnbxAmount = _vault.withdrawFor(msg.sender, address(this), amount);

        uint256 bnbxBalance = _bnbxToken.balanceOf(address(this));
        require(bnbxAmount <= bnbxBalance, "insufficient bnbx balance in bnbx router");
        _stakeManager.requestWithdraw(bnbxAmount);
        emit Withdrawal(msg.sender, recipient, _wBnbAddress, amount);
        return bnbxAmount;
    }
    // withdrawal BNBx
    /// @param recipient address to receive withdrawn BNBx
    /// @param amount in BNB
    function withdrawBnbx(address recipient, uint256 amount)
    external
    override
    nonReentrant
    returns (uint256 bnbxAmount)
    {
        bnbxAmount = _vault.withdrawFor(msg.sender, recipient, amount);
        emit Withdrawal(msg.sender, recipient, address(_bnbxToken), bnbxAmount);
        return bnbxAmount;
    }

    // SD Comment : Hope this is not required ?
    // function withdrawFor(address recipient, uint256 amount)
    // external
    // override
    // nonReentrant
    // onlyProvider
    // returns (uint256 realAmount)
    // {
    //     realAmount = _vault.withdrawFor(msg.sender, address(this), amount);
    //     _stakeManager.requestWithdraw(realAmount); // realAmount -> BNB
    //     emit Withdrawal(msg.sender, recipient, _wBnbAddress, realAmount);
    //     return realAmount;
    // }


    function getYieldFor(address account) external view returns(uint256) {
        return _vault.getYieldFor(account);
    }

    // SD Comment : Is this required? What should it return ?
    // function getPendingWithdrawalOf(address account)
    // external
    // view
    // returns (uint256)
    // {
    //     return _stakeManager.pendingUnstakesOf(account);
    // }

    function changeVault(address vault) external onlyOwner {
        // update allowances
        _bnbxToken.approve(address(_vault), 0);
        _vault = IVault(vault);
        _bnbxToken.approve(address(_vault), type(uint256).max);
        emit ChangeVault(vault);
    }

    function changeStakeManager(address stakeManager) external onlyOwner {
        // update allowances
        _bnbxToken.approve(address(_stakeManager), 0);
        _stakeManager = IStakeManager(stakeManager);
        _bnbxToken.approve(address(_stakeManager), type(uint256).max);
        emit ChangeStakeManager(stakeManager);
    }
    function changeProvider(address provider) external onlyOwner {
        _provider = provider;
        emit ChangeProvider(provider);
    }
    function getProvider() external view returns(address) {
        return _provider;
    }
    function getCeToken() external view returns(address) {
        return address(_ceToken);
    }
    function getWbnbAddress() external view returns(address) {
        return _wBnbAddress;
    }
    function getBnbxToken() external view returns(address) {
        return address(_bnbxToken);
    }
    function getStakeManagerAddress() external view returns(address) {
        return address(_stakeManager);
    }
    function getVaultAddress() external view returns(address) {
        return address(_vault);
    }
}
