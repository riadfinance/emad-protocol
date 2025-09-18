// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EMAD.sol";
import "../src/libraries/Errors.sol";

contract EMADTest is Test {
    EMAD public emad;
    address public owner;
    address public minter;
    address public user1;
    address public user2;
    
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);
    event MintingPaused(bool status);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        owner = address(this);
        minter = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        
        emad = new EMAD();
    }
    
    function testInitialState() public view {
        assertEq(emad.name(), "E-MAD Digital Dirham");
        assertEq(emad.symbol(), "EMAD");
        assertEq(emad.decimals(), 18);
        assertEq(emad.totalSupply(), 1_000_000 * 10**18);
        assertEq(emad.owner(), owner);
        assertEq(emad.minter(), owner);
        assertFalse(emad.mintingPaused());
    }
    
    function testSetMinter() public {
        vm.expectEmit(true, true, false, true);
        emit MinterUpdated(owner, minter);
        
        emad.setMinter(minter);
        assertEq(emad.minter(), minter);
    }
    
    function testOnlyOwnerCanSetMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        emad.setMinter(minter);
    }
    
    function testMint() public {
        emad.setMinter(minter);
        
        uint256 mintAmount = 100 * 10**18;
        uint256 initialBalance = emad.balanceOf(user1);
        
        vm.prank(minter);
        emad.mint(user1, mintAmount);
        
        assertEq(emad.balanceOf(user1), initialBalance + mintAmount);
    }
    
    function testOnlyMinterCanMint() public {
        uint256 mintAmount = 100 * 10**18;
        
        vm.prank(user1);
        vm.expectRevert(Errors.UnauthorizedMinter.selector);
        emad.mint(user1, mintAmount);
    }
    
    function testCannotMintAboveMaxSupply() public {
        uint256 mintAmount = emad.MAX_SUPPLY();
        
        vm.expectRevert(Errors.ExceedsMaxSupply.selector);
        emad.mint(user1, mintAmount);
    }
    
    function testBurn() public {
        uint256 burnAmount = 100 * 10**18;
        
        // First mint some tokens to owner
        emad.mint(owner, burnAmount);
        
        uint256 initialSupply = emad.totalSupply();
        uint256 initialBalance = emad.balanceOf(owner);
        
        emad.burn(burnAmount);
        
        assertEq(emad.totalSupply(), initialSupply - burnAmount);
        assertEq(emad.balanceOf(owner), initialBalance - burnAmount);
    }
    
    function testToggleMinting() public {
        // Initially not paused
        assertFalse(emad.mintingPaused());
        
        vm.expectEmit(false, false, false, true);
        emit MintingPaused(true);
        
        emad.toggleMinting();
        assertTrue(emad.mintingPaused());
        
        // Try to mint while paused
        vm.expectRevert(Errors.MintingPaused.selector);
        emad.mint(user1, 100 * 10**18);
        
        // Toggle back
        vm.expectEmit(false, false, false, true);
        emit MintingPaused(false);
        
        emad.toggleMinting();
        assertFalse(emad.mintingPaused());
        
        // Should be able to mint again
        emad.mint(user1, 100 * 10**18);
    }
    
    function testTransfer() public {
        uint256 amount = 100 * 10**18;
        emad.transfer(user1, amount);
        
        assertEq(emad.balanceOf(user1), amount);
        assertEq(emad.balanceOf(owner), 1_000_000 * 10**18 - amount);
    }
    
    function testApproveAndTransferFrom() public {
        uint256 amount = 100 * 10**18;
        
        emad.approve(user1, amount);
        assertEq(emad.allowance(owner, user1), amount);
        
        vm.prank(user1);
        emad.transferFrom(owner, user2, amount);
        
        assertEq(emad.balanceOf(user2), amount);
        assertEq(emad.allowance(owner, user1), 0);
    }
}