// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IOracle.sol";

contract MockOracle is IOracle {
    uint256 private price;
    uint8 public decimals = 8;
    
    function setPrice(uint256 _price) external {
        uint256 oldPrice = price;
        price = _price;
        emit PriceUpdated(oldPrice, _price);
    }
    
    function getPrice() external view returns (uint256) {
        return price;
    }
    
    function updatePrice(uint256 newPrice) external {
        uint256 oldPrice = price;
        price = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }
}