// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathUtils
 * @notice Math utilities for E-MAD protocol
 */
library MathUtils {
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PERCENTAGE_BASE = 10000;
    
    /**
     * @notice Calculate percentage with precision
     */
    function percentage(
        uint256 value,
        uint256 percent
    ) internal pure returns (uint256) {
        return (value * percent) / PERCENTAGE_BASE;
    }
    
    /**
     * @notice Safe division with rounding
     */
    function divRound(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        return (a + b / 2) / b;
    }
    
    /**
     * @notice Calculate compound interest
     */
    function compound(
        uint256 principal,
        uint256 rate,
        uint256 periods
    ) internal pure returns (uint256) {
        uint256 result = principal;
        for (uint256 i = 0; i < periods; i++) {
            result = (result * (PERCENTAGE_BASE + rate)) / PERCENTAGE_BASE;
        }
        return result;
    }
}