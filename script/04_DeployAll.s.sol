// script/04_DeployAll.s.sol - MASTER DEPLOYMENT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADVault.sol";
import "../src/EMADMinter.sol";
import "../src/MockOracle.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy EMAD Token
        EMAD emad = new EMAD();
        console.log(" EMAD deployed:", address(emad));
        
        // 2. Deploy Vault
        EMADVault vault = new EMADVault(
            address(emad),
            treasury,
            1000000000 * 10**18
        );
        console.log(" Vault deployed:", address(vault));
        
        // 3. Deploy Oracle
        MockOracle oracle = new MockOracle();
        oracle.setPrice(1 * 10**8);
        console.log(" Oracle deployed:", address(oracle));
        
        // 4. Deploy Minter
        EMADMinter minter = new EMADMinter(
            address(emad),
            address(vault),
            treasury,
            address(oracle)
        );
        console.log(" Minter deployed:", address(minter));
        
        // 5. Setup permissions
        emad.setMinter(address(minter));
        console.log(" Minter permissions set");
        
        console.log("\n DEPLOYMENT COMPLETE! ");
        console.log("=====================================");
        console.log("EMAD Token:", address(emad));
        console.log("Vault:", address(vault));
        console.log("Minter:", address(minter));
        console.log("Oracle:", address(oracle));
        console.log("=====================================");
        console.log("\n Add these to your .env file!");
        
        vm.stopBroadcast();
    }
}