// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EMADMinter.sol";
import "../src/EMAD.sol";
import "../src/libraries/Errors.sol";

contract MinterTest is Test {
    EMADMinter public minter;
    EMAD public emad;
    
    address public owner;
    address public vault;
    address public operator;
    address public guardian;
    address public user;
    
    function setUp() public {
        owner = address(this);
        vault = address(0x1);
        operator = address(0x2);
        guardian = address(0x3);
        user = address(0x4);
        
        // Deploy EMAD token
        emad = new EMAD();
        
        // Deploy Minter (need 4 params: emad, vault, treasury, oracle)
        address treasury = address(0x5);
        address oracle = address(0x6);
        minter = new EMADMinter(address(emad), vault, treasury, oracle);
        
        // Set minter as the EMAD minter
        emad.setMinter(address(minter));
        
        // Setup roles
        minter.grantRole(minter.OPERATOR_ROLE(), operator);
        minter.grantRole(minter.GUARDIAN_ROLE(), guardian);
    }
    
    function testInitialState() public view {
        assertEq(address(minter.EMAD()), address(emad));
        assertEq(minter.vault(), vault);
        assertTrue(minter.hasRole(minter.DEFAULT_ADMIN_ROLE(), owner));
    }
}
