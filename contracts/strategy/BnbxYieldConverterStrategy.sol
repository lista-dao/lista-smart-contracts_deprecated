//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../masterVault/interfaces/IMasterVault.sol";
import "../bnbx/interfaces/IStakeManager.sol";
import "../bnbx/interfaces/IBnbxToken.sol";
import "../bnbx/interfaces/IBnbxRouter.sol";
import "./BaseStrategy.sol";

contract BnbxYieldConverterStrategy is BaseStrategy {

    IBnbxRouter private _bnbxRouter;
    IBnbxToken private _bnbxToken;
    IStakeManager private _stakeManager; 
    IMasterVault public vault;

    event StakeManagerChanged(address stakeManager);
    event BnbxRouterChanged(address bnbxRouter);

    /// @dev initialize function - Constructor for Upgradable contract, can be only called once during deployment
    /// @param destination Address of the bnbx router contract
    /// @param feeRecipient Address of the fee recipient
    /// @param underlyingToken Address of the underlying token(wBNB)
    /// @param bnbxToken Address of BNBx token
    /// @param masterVault Address of the masterVault contract
    /// @param stakeManager Address of stakeManager contract
    function initialize(
        address destination,
        address feeRecipient,
        address underlyingToken,
        address bnbxToken,
        address masterVault,
        address stakeManager
    ) public initializer {
        __BaseStrategy_init(destination, feeRecipient, underlyingToken);
        _bnbxRouter = IBnbxRouter(destination);
        _bnbxToken = IBnbxToken(bnbxToken);
        _stakeManager = IStakeManager(stakeManager);
        vault = IMasterVault(masterVault);
        // underlying.approve(address(destination), type(uint256).max);
        // underlying.approve(address(vault), type(uint256).max);
        _bnbxToken.approve(stakeManager, type(uint256).max);
    }

    /**
     * Modifiers
     */
    modifier onlyVault() {
        require(msg.sender == address(vault), "!vault");
        _;
    }

    /// @dev deposits the given amount of underlying tokens into ceros
    function deposit() external payable onlyVault returns(uint256 value) {
        // require(amount <= underlying.balanceOf(address(this)), "insufficient balance");
        uint256 amount = msg.value;
        require(amount <= address(this).balance, "insufficient balance");
        return _deposit(amount);
    }

    /// @dev deposits all the available underlying tokens into ceros
    function depositAll() external payable onlyVault returns(uint256 value) {
        // uint256 amount = underlying.balanceOf(address(this));
        // return _deposit(amount);
        return _deposit(address(this).balance);
    }

    /// @dev internal function to deposit the given amount of underlying tokens into ceros
    /// @param amount amount of underlying tokens
    function _deposit(uint256 amount) internal returns (uint256 value) {
        require(!depositPaused, "deposits are paused");
        require(amount > 0, "invalid amount");
        if (canDeposit(amount)) {
            return _bnbxRouter.deposit{value: amount}();
        }
    }

    /// @dev withdraws the given amount of underlying tokens from ceros and transfers to masterVault
    /// @param amount amount of underlying tokens
    function withdraw(address recipient, uint256 amount) onlyVault external returns(uint256 value) {
        return _withdraw(recipient, amount);
    }

    /// @dev withdraws everything from ceros and transfers to masterVault
    function panic() external onlyStrategist returns (uint256 value) {
        (,, uint256 debt) = vault.strategyParams(address(this));
        return _withdraw(address(vault), debt);
    }

    /// @dev internal function to withdraw the given amount of underlying tokens from ceros
    ///      and transfers to masterVault
    /// @param amount amount of underlying tokens
    /// @return value - returns the amount of underlying tokens withdrawn from ceros
    function _withdraw(address recipient, uint256 amount) internal returns (uint256 value) {
        require(amount > 0, "invalid amount");
        // uint256 wethBalance = underlying.balanceOf(address(this));
        uint256 bnbBalance = address(this).balance;
        if(amount < bnbBalance) {
            // underlying.transfer(recipient, amount); // SD commented
            AddressUpgradeable.sendValue(payable(recipient), amount);
            return amount;
        } else {
            value = _bnbxRouter.withdraw(recipient, amount);
            require(value <= amount, "invalid out amount");
            return amount;
        }
    }

    receive() external payable {}

    function canDeposit(uint256 amount) public pure returns(bool) {
        return (amount > 0);
    }

    function assessDepositFee(uint256 amount) public pure returns(uint256) {
        return amount;
    }

    /// @dev claims yeild from ceros in BNBx and transfers to feeRecipient
    function harvest() external onlyStrategist {
        _harvestTo(rewards);
    }

    /// @dev internal function to claim yeild from ceros in BNBx and transfer them to desired address
    function _harvestTo(address to) private returns(uint256 yield) {
        yield = _bnbxRouter.getYieldFor(address(this));
        if(yield > 0) {
            yield = _bnbxRouter.claim(to);
        }
    }

    /// @dev only owner can change stakeManager address
    /// @param stakeManager new stakeManager address
    function changeStakeManager(address stakeManager) external onlyOwner {
        require(stakeManager != address(0));
        _bnbxToken.approve(address(_stakeManager), 0);
        _stakeManager = IStakeManager(stakeManager);
        _bnbxToken.approve(address(_stakeManager), type(uint256).max);
        emit StakeManagerChanged(stakeManager);
    }

    /// @dev only owner can change bnbxRouter
    /// @param bnbxRouter new bnbx router address
    function changeBnbxRouter(address bnbxRouter) external onlyOwner {
        require(bnbxRouter != address(0));
        // underlying.approve(address(_bnbxRouter), 0); // Stader commented
        destination = bnbxRouter;
        _bnbxRouter = IBnbxRouter(bnbxRouter);
        // underlying.approve(address(_ceRouter), type(uint256).max); // Stader commented
        emit BnbxRouterChanged(bnbxRouter);
    }
}
