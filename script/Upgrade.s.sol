// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADMinter.sol";
import "../src/EMADVault.sol";

/**
 * @title Upgrade Script
 * @notice Script for upgrading EMAD Protocol contracts
 * @dev Run with: forge script script/Upgrade.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
contract Upgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address emadAddress = vm.envAddress("EMAD_ADDRESS");
        address minterAddress = vm.envAddress("MINTER_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        
        console.log("=== EMAD Protocol Upgrade ===");
        console.log("Upgrader:", vm.addr(deployerPrivateKey));
        console.log("Current EMAD:", emadAddress);
        console.log("Current Minter:", minterAddress);
        console.log("Current Vault:", vaultAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example: Deploy new minter and update EMAD token
        console.log("\n1. Deploying new EMADMinter...");
        
        // Get current config
        EMAD emad = EMAD(emadAddress);
        EMADMinter currentMinter = EMADMinter(minterAddress);
        
        // Deploy new minter with same config
        EMADMinter newMinter = new EMADMinter(
            emadAddress,
            address(currentMinter.vault()),
            vm.envAddress("TREASURY_ADDRESS"),
            vm.envAddress("ORACLE_ADDRESS")
        );
        
        console.log("New Minter deployed at:", address(newMinter));
        
        // Update EMAD token to use new minter
        console.log("\n2. Updating minter address...");
        emad.setMinter(address(newMinter));
        console.log(" EMAD minter updated");
        
        vm.stopBroadcast();
        
        console.log("\n=== UPGRADE SUMMARY ===");
        console.log("Old Minter:", minterAddress);
        console.log("New Minter:", address(newMinter));
        console.log("\n Upgrade complete!");
        
        console.log("\n=== UPDATE ENVIRONMENT VARIABLES ===");
        console.log("MINTER_ADDRESS=%s", address(newMinter));
    }
    
    /**
     * @notice Upgrade only the oracle price
     */
    function upgradeOraclePrice() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        uint256 newPrice = vm.envUint("NEW_PRICE"); // e.g., 100000000 for $1.00
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Cast to MockOracle and update price
        (bool success, ) = oracleAddress.call(
            abi.encodeWithSignature("setPrice(uint256)", newPrice)
        );
        
        require(success, "Failed to update oracle price");
        console.log(" Oracle price updated to:", newPrice);
        
        vm.stopBroadcast();
    }
}