// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IEMAD.sol";
import "./libraries/Errors.sol";

/**
 * @title EMAD - Digital Dirham
 * @author RIAD Finance
 * @notice Core E-MAD token with minting rights
 */
contract EMAD is IEMAD, ERC20, Ownable {
    
    // State variables
    address public minter;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion max
    bool public mintingPaused;
    
    // Events
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);
    event MintingPaused(bool status);
    
    modifier onlyMinter() {
        if (msg.sender != minter) revert Errors.UnauthorizedMinter();
        _;
    }
    
    modifier whenNotPaused() {
        if (mintingPaused) revert Errors.MintingPaused();
        _;
    }
    
    constructor() ERC20("E-MAD Digital Dirham", "EMAD") Ownable(msg.sender) {
        // Initial minter is deployer, will be changed to MinterContract
        minter = msg.sender;
        
        // Mint initial supply for liquidity
        _mint(msg.sender, 1_000_000 * 10**18); // 1M EMAD initial
    }
    
    /**
     * @notice Mint new EMAD tokens
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) 
        external 
        override 
        onlyMinter 
        whenNotPaused 
    {
        if (to == address(0)) revert Errors.ZeroAddress();
        if (totalSupply() + amount > MAX_SUPPLY) revert Errors.ExceedsMaxSupply();
        
        _mint(to, amount);
        emit Mint(to, amount);
    }
    
    /**
     * @notice Burn EMAD tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }
    
    /**
     * @notice Update minter address
     * @param newMinter New minter address
     */
    function setMinter(address newMinter) external onlyOwner {
        if (newMinter == address(0)) revert Errors.ZeroAddress();
        
        address oldMinter = minter;
        minter = newMinter;
        
        emit MinterUpdated(oldMinter, newMinter);
    }
    
    /**
     * @notice Pause/unpause minting
     */
    function toggleMinting() external onlyOwner {
        mintingPaused = !mintingPaused;
        emit MintingPaused(mintingPaused);
    }
}