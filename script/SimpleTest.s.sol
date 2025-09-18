// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";
import "../src/EMADMinter.sol";
import "../src/MockOracle.sol";

contract SimpleTest is Script {
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
        
        console.log("=== SIMPLE FUNCTIONALITY TEST ===");
        
        // Test 1: EMAD Properties
        console.log("EMAD Name:", emad.name());
        console.log("EMAD Symbol:", emad.symbol());
        console.log("Total Supply:", emad.totalSupply());
        console.log("Deployer Balance:", emad.balanceOf(deployer));
        
        // Test 2: Oracle
        console.log("Oracle Price:", oracle.getPrice());
        
        // Test 3: Transfer
        address recipient = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        emad.transfer(recipient, 1000 * 10**18);
        console.log("Transfer successful - Recipient balance:", emad.balanceOf(recipient));
        
        // Test 4: Setup minter role
        minter.grantRole(minter.MINTER_ROLE(), deployer);
        console.log("Minter role granted");
        
        // Test 5: Mint via direct EMAD (as owner)
        uint256 directMintAmount = 500 * 10**18;
        emad.mint(deployer, directMintAmount);
        console.log("Direct mint successful");
        
        console.log("=== ALL TESTS PASSED ===");
        
        vm.stopBroadcast();
    }
}