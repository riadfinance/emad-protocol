// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADVault.sol";
import "../src/EMADMinter.sol";
import "../src/MockOracle.sol";

/**
 * @title Deploy Script
 * @notice Main deployment script for EMAD Protocol
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
contract Deploy is Script {
    function run() external returns (address emad, address vault, address minter, address oracle) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        
        console.log("=== EMAD Protocol Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Treasury:", treasury);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy EMAD Token
        console.log("\n1. Deploying EMAD Token...");
        EMAD emadContract = new EMAD();
        emad = address(emadContract);
        console.log(" EMAD deployed at:", emad);
        
        // 2. Deploy Vault
        console.log("\n2. Deploying EMADVault...");
        EMADVault vaultContract = new EMADVault(
            emad,
            treasury,
            1_000_000_000 * 10**18 // 1B debt ceiling
        );
        vault = address(vaultContract);
        console.log(" Vault deployed at:", vault);
        
        // 3. Deploy Oracle (Mock for testing)
        console.log("\n3. Deploying MockOracle...");
        MockOracle oracleContract = new MockOracle();
        oracleContract.setPrice(1 * 10**8); // $1.00 USD
        oracle = address(oracleContract);
        console.log(" Oracle deployed at:", oracle);
        
        // 4. Deploy Minter
        console.log("\n4. Deploying EMADMinter...");
        EMADMinter minterContract = new EMADMinter(
            emad,
            vault,
            treasury,
            oracle
        );
        minter = address(minterContract);
        console.log(" Minter deployed at:", minter);
        
        // 5. Setup permissions
        console.log("\n5. Setting up permissions...");
        emadContract.setMinter(minter);
        console.log(" Minter permissions set");
        
        vm.stopBroadcast();
        
        // 6. Summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("EMAD Token:", emad);
        console.log("EMADVault:", vault);
        console.log("EMADMinter:", minter);
        console.log("MockOracle:", oracle);
        console.log("Treasury:", treasury);
        
        console.log("\n=== ENVIRONMENT VARIABLES ===");
        console.log("Add these to your .env file:");
        console.log("EMAD_ADDRESS=%s", emad);
        console.log("VAULT_ADDRESS=%s", vault);
        console.log("MINTER_ADDRESS=%s", minter);
        console.log("ORACLE_ADDRESS=%s", oracle);
        console.log("\n Deployment complete!");
        
        return (emad, vault, minter, oracle);
    }
}