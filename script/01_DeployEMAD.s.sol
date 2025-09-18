// script/01_DeployEMAD.s.sol
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/EMAD.sol";

contract DeployEMAD is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        EMAD emad = new EMAD();
        
        console.log("=====================================");
        console.log("EMAD Token deployed at:", address(emad));
        console.log("Name:", emad.name());
        console.log("Symbol:", emad.symbol());
        console.log("Initial Supply:", emad.totalSupply());
        console.log("=====================================");
        
        vm.stopBroadcast();
    }
}