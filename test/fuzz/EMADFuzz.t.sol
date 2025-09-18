// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/EMAD.sol";

contract EMADFuzzTest is Test {
    EMAD public emad;
    
    function setUp() public {
        emad = new EMAD();
    }
    
    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= emad.MAX_SUPPLY() - emad.totalSupply());
        
        uint256 initialBalance = emad.balanceOf(to);
        uint256 initialSupply = emad.totalSupply();
        
        emad.mint(to, amount);
        
        assertEq(emad.balanceOf(to), initialBalance + amount);
        assertEq(emad.totalSupply(), initialSupply + amount);
    }
    
    function testFuzzTransfer(address from, address to, uint256 amount) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        
        // Mint tokens to from address
        uint256 mintAmount = 10_000 * 10**18;
        emad.mint(from, mintAmount);
        
        vm.assume(amount <= mintAmount);
        
        uint256 fromInitialBalance = emad.balanceOf(from);
        uint256 toInitialBalance = emad.balanceOf(to);
        
        vm.prank(from);
        emad.transfer(to, amount);
        
        assertEq(emad.balanceOf(from), fromInitialBalance - amount);
        assertEq(emad.balanceOf(to), toInitialBalance + amount);
    }
}
