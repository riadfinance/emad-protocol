// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    function getPrice() external view returns (uint256);
    function decimals() external view returns (uint8);
    function updatePrice(uint256 newPrice) external;
    
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
}