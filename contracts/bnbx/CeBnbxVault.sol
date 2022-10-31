// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ICeBnbxVault.sol";
import "./interfaces/ICeToken.sol";
import "./interfaces/IBnbxToken.sol";
import "./interfaces/IStakeManager.sol";

contract CeBnbxVault is
ICeBnbxVault,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    string private _name;
    // Tokens
    ICeToken private _ceToken; // SD Comment : Used ICeToken interface
    IBnbxToken private _bnbxToken;
    address private _router;
    IStakeManager private _stakeManager;
    mapping(address => uint256) private _claimed; // in BNBx
    mapping(address => uint256) private _depositors; // in BNBx
    mapping(address => uint256) private _ceTokenBalances; // in BNBx // SD Comment : Is this comment right ?
    /**
     * Modifiers
     */
    modifier onlyRouter() {
        require(msg.sender == _router, "Router: not allowed");
        _;
    }
    function initialize(
        string memory name,
        address ceTokenAddress,
        address bnbxAddress,
        address stakeManager
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _name = name;
        _stakeManager = IStakeManager(stakeManager);
        _ceToken = ICeToken(ceTokenAddress);
        _bnbxToken = IBnbxToken(bnbxAddress);
    }
    // deposit
    function deposit(uint256 amount)
    external
    override
    nonReentrant
    returns (uint256)
    {
        return _deposit(msg.sender, amount);
    }

    // deposit
    function depositFor(address recipient, uint256 amount)
    external
    override
    nonReentrant
    onlyRouter
    returns (uint256)
    {
        return _deposit(recipient, amount);
    }
    // deposit
    function _deposit(address account, uint256 amount)
    private
    returns (uint256)
    {
        _bnbxToken.transferFrom(msg.sender, address(this), amount);
        uint256 toMint = _stakeManager.convertBnbXToBnb(amount);
        _depositors[account] += amount; // BNBx
        _ceTokenBalances[account] += toMint;
        //  mint ceToken to recipient
        ICeToken(_ceToken).mint(account, toMint);
        emit Deposited(msg.sender, account, toMint);
        return toMint;
    }
    function claimYieldsFor(address owner, address recipient)
    external
    override
    onlyRouter
    nonReentrant
    returns (uint256)
    {
        return _claimYields(owner, recipient);
    }
    // claimYields
    function claimYields(address recipient)
    external
    override
    nonReentrant
    returns (uint256)
    {
        return _claimYields(msg.sender, recipient);
    }
    function _claimYields(address owner, address recipient)
    private
    returns (uint256)
    {
        uint256 availableYields = this.getYieldFor(owner);
        require(availableYields > 0, "has not got yields to claim");
        // return back BNBx to recipient
        _claimed[owner] += availableYields;
        _bnbxToken.transfer(recipient, availableYields);
        emit Claimed(owner, recipient, availableYields);
        return availableYields;
    }
    // withdraw
    function withdraw(address recipient, uint256 amount)
    external
    override
    nonReentrant
    returns (uint256)
    {
        return _withdraw(msg.sender, recipient, amount);
    }
    // withdraw
    function withdrawFor(
        address owner,
        address recipient,
        uint256 amount
    ) external override nonReentrant onlyRouter returns (uint256) {
        return _withdraw(owner, recipient, amount);
    }
    function _withdraw(
        address owner,
        address recipient,
        uint256 amount
    ) private returns (uint256) {
        uint256 bnbxAmount = _stakeManager.convertBnbToBnbX(amount);
        require(
            _bnbxToken.balanceOf(address(this)) >= bnbxAmount,
            "not such amount in the vault"
        );
        uint256 balance = _ceTokenBalances[owner];
        require(balance >= amount, "insufficient balance");
        _ceTokenBalances[owner] -= amount; // BNB
        // burn ceToken from owner
        ICeToken(_ceToken).burn(owner, amount);
        _depositors[owner] -= bnbxAmount; // BNBx
        _bnbxToken.transfer(recipient, bnbxAmount);
        emit Withdrawn(owner, recipient, bnbxAmount);
        return bnbxAmount;
    }
    function getTotalAmountInVault() external view override returns (uint256) {
        return _bnbxToken.balanceOf(address(this));
    }
    // yield + principal = deposited(before claim)
    // BUT after claim yields: available_yield + principal == deposited - claimed
    // available_yield = yield - claimed;
    // principal = deposited*(current_ratio/init_ratio)=cetoken.balanceOf(account)*current_ratio;
    function getPrincipalOf(address account)
    external
    view
    override
    returns (uint256) // in BNBx
    {
        return _stakeManager.convertBnbToBnbX(_ceTokenBalances[account]);
    }
    // yield = deposited*(1-current_ratio/init_ratio) = cetoken.balanceOf*init_ratio-cetoken.balanceOf*current_ratio
    // yield = cetoken.balanceOf*(init_ratio-current_ratio) = amount(in aBNBc) - amount(in aBNBc)
    function getYieldFor(address account)
    external
    view
    override
    returns (uint256)
    {
        uint256 principal = this.getPrincipalOf(account);
        if (principal >= _depositors[account]) {
            return 0;
        }
        uint256 totalYields = _depositors[account] - principal;
        if (totalYields <= _claimed[account]) {
            return 0;
        }
        return totalYields - _claimed[account];
    }
    function getCeTokenBalanceOf(address account)
    external
    view
    returns (uint256)
    {
        return _ceTokenBalances[account];
    }
    function getDepositOf(address account) external view returns (uint256) {
        return _depositors[account];
    }
    function getClaimedOf(address account) external view returns (uint256) {
        return _claimed[account];
    }
    function changeRouter(address router) external onlyOwner {
        _router = router;
        emit RouterChanged(router);
    }
    function changeStakeManager(address stakeManager) external onlyOwner {
        _stakeManager = IStakeManager(stakeManager);
        emit StakeManagerChanged(stakeManager);
    }
    function getName() external view returns (string memory) {
        return _name;
    }
    function getCeToken() external view returns(address) {
        return address(_ceToken);
    }
    function getBnbxAddress() external view returns(address) {
        return address(_bnbxToken);
    }
    function getRouter() external view returns(address) {
        return address(_router);
    }
    function getStakeManager() external view returns(address) {
        return address(_stakeManager);
    }
}
