// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EMADVault.sol";
import "../src/EMAD.sol";

contract VaultTest is Test {
    EMADVault public vault;
    EMAD public emad;
    
    address public owner;
    address public treasury;
    address public user;
    
    function setUp() public {
        owner = address(this);
        treasury = address(0x1);
        user = address(0x2);
        
        // Deploy EMAD token
        emad = new EMAD();
        
        // Deploy Vault
        vault = new EMADVault(
            address(emad),
            treasury,
            1_000_000_000 * 10**18 // 1B debt ceiling
        );
    }
    
    function testInitialState() public view {
        assertEq(address(vault.EMAD()), address(emad));
        assertEq(vault.treasury(), treasury);
        assertEq(vault.debtCeiling(), 1_000_000_000 * 10**18);
    }
}
