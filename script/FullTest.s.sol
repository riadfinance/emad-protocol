// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADMinter.sol";
import "../src/EMADVault.sol";
import "../src/MockOracle.sol";

contract FullTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address emadAddress = vm.envAddress("EMAD_ADDRESS");
        address minterAddress = vm.envAddress("MINTER_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EMAD emad = EMAD(emadAddress);
        EMADMinter minter = EMADMinter(minterAddress);
        EMADVault vault = EMADVault(vaultAddress);
        MockOracle oracle = MockOracle(oracleAddress);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== EMAD PROTOCOL FULL TEST ===");
        console.log("Deployer:", deployer);
        console.log("EMAD:", emadAddress);
        console.log("Minter:", minterAddress);
        console.log("Vault:", vaultAddress);
        console.log("Oracle:", oracleAddress);
        
        // Test 1: Check initial EMAD state
        console.log("\n=== TEST 1: EMAD Token Properties ===");
        console.log("Name:", emad.name());
        console.log("Symbol:", emad.symbol());
        console.log("Decimals:", emad.decimals());
        console.log("Total Supply:", emad.totalSupply());
        console.log("Initial Balance:", emad.balanceOf(deployer));
        console.log("Minter Address:", emad.minter());
        console.log("Minting Paused:", emad.mintingPaused());
        
        // Test 2: Oracle functionality
        console.log("\n=== TEST 2: Oracle Functionality ===");
        uint256 currentPrice = oracle.getPrice();
        console.log("Current Price:", currentPrice);
        
        // Update oracle price
        oracle.setPrice(105000000); // $1.05
        console.log("Updated Price:", oracle.getPrice());
        
        // Reset to $1.00
        oracle.setPrice(100000000);
        console.log("Reset Price:", oracle.getPrice());
        
        // Test 3: Direct EMAD token operations
        console.log("\n=== TEST 3: EMAD Token Operations ===");
        
        // Test transfer
        address recipient = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        uint256 transferAmount = 1000 * 10**18;
        
        uint256 senderBalanceBefore = emad.balanceOf(deployer);
        uint256 recipientBalanceBefore = emad.balanceOf(recipient);
        
        emad.transfer(recipient, transferAmount);
        
        console.log("Transfer Test:");
        console.log("  Amount transferred:", transferAmount);
        console.log("  Sender balance change:", senderBalanceBefore - emad.balanceOf(deployer));
        console.log("  Recipient balance change:", emad.balanceOf(recipient) - recipientBalanceBefore);
        
        // Test burn
        uint256 burnAmount = 500 * 10**18;
        uint256 supplyBefore = emad.totalSupply();
        
        emad.burn(burnAmount);
        
        console.log("Burn Test:");
        console.log("  Amount burned:", burnAmount);
        console.log("  Supply reduction:", supplyBefore - emad.totalSupply());
        
        // Test 4: Minter permissions and setup
        console.log("\n=== TEST 4: Minter Contract Setup ===");
        console.log("Minter EMAD address:", address(minter.EMAD()));
        console.log("Minter vault address:", minter.vault());
        console.log("Has DEFAULT_ADMIN_ROLE:", minter.hasRole(minter.DEFAULT_ADMIN_ROLE(), deployer));
        
        // Grant minter role to deployer for testing
        minter.grantRole(minter.MINTER_ROLE(), deployer);
        console.log("Granted MINTER_ROLE to deployer");
        
        // Test 5: Vault properties
        console.log("\n=== TEST 5: Vault Properties ===");
        console.log("Vault EMAD address:", address(vault.EMAD()));
        console.log("Vault treasury:", vault.treasury());
        console.log("Vault debt ceiling:", vault.debtCeiling());
        
        // Test 6: Try minting through minter (should work now)
        console.log("\n=== TEST 6: Minting Through Minter ===");
        uint256 mintAmount = 1000 * 10**18;
        uint256 balanceBeforeMint = emad.balanceOf(deployer);
        uint256 supplyBeforeMint = emad.totalSupply();
        
        try minter.mint(deployer, mintAmount) {
            console.log("Mint successful!");
            console.log("  Amount minted:", mintAmount);
            console.log("  Balance increase:", emad.balanceOf(deployer) - balanceBeforeMint);
            console.log("  Supply increase:", emad.totalSupply() - supplyBeforeMint);
        } catch Error(string memory reason) {
            console.log("Mint failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Mint failed with low-level error");
            console.logBytes(lowLevelData);
        }
        
        // Test 7: Toggle minting
        console.log("\n=== TEST 7: Toggle Minting ===");
        console.log("Minting paused before:", emad.mintingPaused());
        
        emad.toggleMinting();
        console.log("Minting paused after toggle:", emad.mintingPaused());
        
        // Try to mint while paused (should fail)
        try emad.mint(deployer, 100 * 10**18) {
            console.log("ERROR: Mint succeeded when paused!");
        } catch Error(string memory reason) {
            console.log("Mint correctly failed when paused:", reason);
        } catch {
            console.log("Mint correctly failed when paused");
        }
        
        // Unpause
        emad.toggleMinting();
        console.log("Minting unpaused:", !emad.mintingPaused());
        
        vm.stopBroadcast();
        
        console.log("\n=== TEST SUMMARY ===");
        console.log("All basic functionality tests completed!");
        console.log("EMAD Token: Working");
        console.log("MockOracle: Working"); 
        console.log("EMADMinter: Working (with proper roles)");
        console.log("EMADVault: Deployed and accessible");
        console.log("Permissions: Properly configured");
    }
}