// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADMinter.sol";
import "../src/MockOracle.sol";

contract WorkingTest is Script {
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
        
        console.log("=== WORKING FUNCTIONALITY TEST ===");
        
        // Test 1: EMAD Properties
        console.log("EMAD Name:", emad.name());
        console.log("Total Supply:", emad.totalSupply());
        console.log("Deployer Balance:", emad.balanceOf(deployer));
        console.log("Current Minter:", emad.minter());
        
        // Test 2: Oracle
        console.log("Oracle Price: $", oracle.getPrice() / 1e8);
        
        // Test 3: Transfer
        address recipient = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        emad.transfer(recipient, 1000 * 10**18);
        console.log("Transferred 1000 EMAD to recipient");
        console.log("Recipient balance:", emad.balanceOf(recipient) / 1e18);
        
        // Test 4: Grant minter role
        minter.grantRole(minter.MINTER_ROLE(), deployer);
        console.log("Granted MINTER_ROLE to deployer");
        
        // Test 5: Try minting through minter contract
        uint256 mintAmount = 500 * 10**18;
        uint256 balanceBefore = emad.balanceOf(deployer);
        
        console.log("Attempting to mint 500 EMAD...");
        console.log("Balance before mint:", balanceBefore / 1e18);
        
        // This should work as we have MINTER_ROLE
        minter.mint(deployer, mintAmount);
        
        uint256 balanceAfter = emad.balanceOf(deployer);
        console.log("Balance after mint:", balanceAfter / 1e18);
        console.log("Successfully minted:", (balanceAfter - balanceBefore) / 1e18);
        
        // Test 6: Burn tokens
        uint256 burnAmount = 200 * 10**18;
        uint256 supplyBefore = emad.totalSupply();
        
        emad.burn(burnAmount);
        console.log("Burned 200 EMAD");
        console.log("Supply before burn:", supplyBefore / 1e18);
        console.log("Supply after burn:", emad.totalSupply() / 1e18);
        
        // Test 7: Toggle minting
        console.log("Minting paused:", emad.mintingPaused());
        emad.toggleMinting();
        console.log("After toggle - Minting paused:", emad.mintingPaused());
        emad.toggleMinting(); // Toggle back
        console.log("Toggled back - Minting paused:", emad.mintingPaused());
        
        console.log("\n=== ALL TESTS COMPLETED SUCCESSFULLY ===");
        
        vm.stopBroadcast();
    }
}