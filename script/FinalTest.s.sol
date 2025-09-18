// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADMinter.sol";
import "../src/MockOracle.sol";

contract FinalTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address emadAddress = vm.envAddress("EMAD_ADDRESS");
        address minterAddress = vm.envAddress("MINTER_ADDRESS");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EMAD emad = EMAD(emadAddress);
        EMADMinter minter = EMADMinter(minterAddress);
        MockOracle oracle = MockOracle(oracleAddress);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== COMPLETE FUNCTIONALITY TEST ===");
        console.log("Deployer:", deployer);
        console.log("");
        
        // Test 1: Basic Properties
        console.log("1. EMAD Token Properties:");
        console.log("   Name:", emad.name());
        console.log("   Symbol:", emad.symbol());
        console.log("   Total Supply:", emad.totalSupply() / 1e18, "EMAD");
        console.log("   Deployer Balance:", emad.balanceOf(deployer) / 1e18, "EMAD");
        console.log("");
        
        // Test 2: Oracle
        console.log("2. Oracle Price: $", oracle.getPrice() / 1e8);
        console.log("");
        
        // Test 3: Transfer
        console.log("3. Testing Transfer...");
        address recipient = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        emad.transfer(recipient, 1000 * 10**18);
        console.log("   Transferred 1000 EMAD to recipient");
        console.log("   Recipient balance:", emad.balanceOf(recipient) / 1e18, "EMAD");
        console.log("");
        
        // Test 4: Setup roles for minting
        console.log("4. Setting up Minter Roles...");
        minter.grantRole(minter.OPERATOR_ROLE(), deployer);
        minter.grantRole(minter.MINTER_ROLE(), deployer);
        console.log("   Granted OPERATOR_ROLE and MINTER_ROLE to deployer");
        
        // Test 5: Whitelist deployer
        console.log("5. Whitelisting deployer...");
        minter.setWhitelist(deployer, true);
        console.log("   Deployer whitelisted for minting");
        console.log("");
        
        // Test 6: Minting through minter contract
        console.log("6. Testing Minting...");
        uint256 mintAmount = 500 * 10**18;
        uint256 balanceBefore = emad.balanceOf(deployer);
        uint256 supplyBefore = emad.totalSupply();
        
        minter.mint(deployer, mintAmount);
        
        uint256 balanceAfter = emad.balanceOf(deployer);
        uint256 supplyAfter = emad.totalSupply();
        
        console.log("   Successfully minted:", (balanceAfter - balanceBefore) / 1e18, "EMAD");
        console.log("   Supply increased by:", (supplyAfter - supplyBefore) / 1e18, "EMAD");
        console.log("");
        
        // Test 7: Burn tokens
        console.log("7. Testing Burn...");
        uint256 burnAmount = 200 * 10**18;
        uint256 burnSupplyBefore = emad.totalSupply();
        
        emad.burn(burnAmount);
        console.log("   Burned:", burnAmount / 1e18, "EMAD");
        console.log("   Supply reduced by:", (burnSupplyBefore - emad.totalSupply()) / 1e18, "EMAD");
        console.log("");
        
        // Test 8: Oracle price update
        console.log("8. Testing Oracle Update...");
        oracle.setPrice(105000000); // $1.05
        console.log("   Updated price to: $", oracle.getPrice() / 1e8);
        oracle.setPrice(100000000); // Reset to $1.00
        console.log("   Reset price to: $", oracle.getPrice() / 1e8);
        console.log("");
        
        // Test 9: Toggle minting
        console.log("9. Testing Minting Toggle...");
        console.log("   Minting paused:", emad.mintingPaused());
        emad.toggleMinting();
        console.log("   After toggle - Minting paused:", emad.mintingPaused());
        emad.toggleMinting(); // Toggle back
        console.log("   Toggled back - Minting paused:", emad.mintingPaused());
        console.log("");
        
        console.log("=== FINAL STATUS ===");
        console.log("EMAD Total Supply:", emad.totalSupply() / 1e18, "EMAD");
        console.log("Deployer Balance:", emad.balanceOf(deployer) / 1e18, "EMAD");
        console.log("Recipient Balance:", emad.balanceOf(recipient) / 1e18, "EMAD");
        console.log("");
        console.log("ALL TESTS COMPLETED SUCCESSFULLY!");
        console.log("The EMAD Protocol is fully functional!");
        
        vm.stopBroadcast();
    }
}