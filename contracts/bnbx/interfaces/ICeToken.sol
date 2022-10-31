// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ICeToken is IERC20Upgradeable {
    /**
     * Events
     */

    event VaultChanged(address vault);

    function burn(address account, uint256 amount) external;

    function mint(address account, uint256 amount) external;

    function changeVault(address vault) external;

    function getVaultAddress() external view returns (address);
}
