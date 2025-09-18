// script/TestInteractions.s.sol
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IEMAD.sol";
import "../src/EMADMinter.sol";

contract TestInteractions is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address emadAddress = vm.envAddress("EMAD_ADDRESS");
        address minterAddress = vm.envAddress("MINTER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        IEMAD emad = IEMAD(emadAddress);
        EMADMinter minter = EMADMinter(minterAddress);
        
        // Test minting
        console.log("Testing mint function...");
        uint256 balanceBefore = emad.balanceOf(msg.sender);
        console.log("Balance before:", balanceBefore);
        
        // Mint 1000 EMAD
        minter.mint(msg.sender, 1000 * 10**18);
        
        uint256 balanceAfter = emad.balanceOf(msg.sender);
        console.log("Balance after:", balanceAfter);
        console.log("Minted:", balanceAfter - balanceBefore);
        
        vm.stopBroadcast();
    }
}