// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;

import "../../ceros/interfaces/IVault.sol";

interface ICeBnbxVault is IVault{
    event StakeManagerChanged(address stakeManager);
}
