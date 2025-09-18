// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IEMAD is IERC20 {
    // Only the ESSENTIAL functions you'll actually use
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
}