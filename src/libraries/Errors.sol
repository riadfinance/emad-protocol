// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors
 * @notice Custom errors for gas efficiency (cheaper than strings)
 */
library Errors {
    // Token errors
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidAmount();
    error ZeroAddress();
    error SelfTransfer();
    
    // Minting errors
    error MintingPaused();
    error ExceedsMaxSupply();
    error UnauthorizedMinter();
    
    // Oracle errors
    error StalePrice();
    error InvalidPrice();
    error OracleOffline();
    
    // Access control
    error Unauthorized();
    error OnlyOwner();
    error OnlyMinter();
    
    // State errors
    error AlreadyInitialized();
    error NotInitialized();
    error Paused();
    error Expired();
    
    // Governance errors
    error InsufficientVotingPower();
    error ExceedsTreasuryLimit();
    error ProposalNotFound();
    error ProposalVetoed();
    error InvalidProposalState();
    error VetoPeriodExpired();
    error EmergencyMode();
    error NoRewards();
    
    // Additional errors
    error MaxSupplyExceeded();
    error InvalidCollateral();
    error CollateralCapExceeded();
    error DebtCeilingExceeded();
    error UnsafePosition();
    error NoDebt();
    error InsufficientCollateral();
    error PositionSafe();
    error InvalidRatio();
    error Blacklisted();
    error NotWhitelisted();
    error EmergencyPause();
    error AlreadyProcessed();
    error AmountTooLarge();
    error AmountTooSmall();
    error CooldownActive();
    error DailyLimitExceeded();
    error HourlyLimitExceeded();
    error PriceDeviationTooHigh();
}