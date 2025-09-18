// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMADMinter.sol";
import "../src/MockOracle.sol";

contract DeployMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address emadAddress = vm.envAddress("EMAD_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // If no oracle provided, deploy a mock one
        if (oracleAddress == address(0)) {
            MockOracle oracle = new MockOracle();
            oracle.setPrice(1 * 10**8); // $1 USD
            oracleAddress = address(oracle);
            console.log("MockOracle deployed at:", oracleAddress);
        }
        
        EMADMinter minter = new EMADMinter(
            emadAddress,
            vaultAddress,
            treasury,
            oracleAddress
        );
        
        console.log("=====================================");
        console.log("EMADMinter deployed at:", address(minter));
        console.log("EMAD Token:", emadAddress);
        console.log("Vault:", vaultAddress);
        console.log("Treasury:", treasury);
        console.log("Oracle:", oracleAddress);
        console.log("=====================================");
        
        vm.stopBroadcast();
    }
}