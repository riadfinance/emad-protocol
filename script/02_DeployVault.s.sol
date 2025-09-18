// script/02_DeployVault.s.sol
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMADVault.sol";

contract DeployVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address emadAddress = vm.envAddress("EMAD_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EMADVault vault = new EMADVault(
            emadAddress,
            treasury,
            1000000000 * 10**18 // 1B debt ceiling
        );
        
        console.log("=====================================");
        console.log("EMADVault deployed at:", address(vault));
        console.log("EMAD Token:", emadAddress);
        console.log("Treasury:", treasury);
        console.log("Debt Ceiling:", vault.debtCeiling());
        console.log("=====================================");
        
        vm.stopBroadcast();
    }
}