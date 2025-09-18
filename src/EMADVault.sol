// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IEMAD.sol";
import "./interfaces/IOracle.sol";
import "./libraries/Errors.sol";
import "./libraries/TransferHelper.sol";

/**
 * @title EMADVault
 * @author RIAD Finance
 * @notice Manages collateral for E-MAD stablecoin
 * @dev Supports multiple collateral types with different ratios
 */
contract EMADVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ State Variables ============
    
    IEMAD public immutable EMAD;
    
    struct CollateralInfo {
        bool accepted;              // Is this collateral accepted?
        uint256 collateralRatio;   // Required ratio (150 = 150%)
        uint256 liquidationRatio;  // Liquidation threshold (120 = 120%)
        uint256 stabilityFee;      // Fee in basis points (30 = 0.3%)
        IOracle priceFeed;         // Oracle for price
        uint256 cap;               // Max amount of this collateral
        uint256 totalDeposited;    // Current deposited amount
    }
    
    struct Position {
        uint256 collateralAmount;  // Amount of collateral deposited
        uint256 debtAmount;        // Amount of EMAD minted
        uint256 lastUpdate;        // Last interaction timestamp
    }
    
    // Collateral token address => CollateralInfo
    mapping(address => CollateralInfo) public collateralInfo;
    
    // User => Collateral => Position
    mapping(address => mapping(address => Position)) public positions;
    
    // Protocol parameters
    uint256 public constant PRECISION = 1e18;
    uint256 public constant PERCENTAGE_BASE = 10000;
    uint256 public constant MIN_COLLATERAL_RATIO = 11000; // 110%
    uint256 public constant LIQUIDATION_PENALTY = 500;     // 5%
    uint256 public constant LIQUIDATION_DISCOUNT = 300;    // 3% discount for liquidators
    
    // Protocol state
    uint256 public totalDebt;              // Total EMAD minted
    uint256 public debtCeiling;            // Max total debt allowed
    uint256 public mintFee = 30;          // 0.3% mint fee
    uint256 public redeemFee = 30;        // 0.3% redeem fee
    bool public paused;
    
    // Treasury and fees
    address public treasury;
    uint256 public accumulatedFees;
    
    // Supported collaterals list
    address[] public collateralTokens;
    
    // ============ Events ============
    
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateral, uint256 amount);
    event EMADMinted(address indexed user, address indexed collateral, uint256 amount);
    event EMADBurned(address indexed user, address indexed collateral, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, address indexed collateral, uint256 debtCovered);
    event CollateralAdded(address indexed collateral, uint256 ratio, address oracle);
    event CollateralUpdated(address indexed collateral, uint256 newRatio);
    event FeesCollected(uint256 amount);
    
    // ============ Modifiers ============
    
    modifier notPaused() {
        if (paused) revert Errors.Paused();
        _;
    }
    
    modifier onlyAcceptedCollateral(address collateral) {
        if (!collateralInfo[collateral].accepted) revert Errors.InvalidCollateral();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _emad, address _treasury, uint256 _debtCeiling) Ownable(msg.sender) {
        if (_emad == address(0) || _treasury == address(0)) revert Errors.ZeroAddress();
        
        EMAD = IEMAD(_emad);
        treasury = _treasury;
        debtCeiling = _debtCeiling;
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Deposit collateral into vault
     * @param collateral Address of collateral token
     * @param amount Amount to deposit
     */
    function depositCollateral(
        address collateral,
        uint256 amount
    ) external nonReentrant notPaused onlyAcceptedCollateral(collateral) {
        if (amount == 0) revert Errors.InvalidAmount();
        
        CollateralInfo storage info = collateralInfo[collateral];
        if (info.totalDeposited + amount > info.cap) revert Errors.CollateralCapExceeded();
        
        // Transfer collateral from user
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update position
        positions[msg.sender][collateral].collateralAmount += amount;
        positions[msg.sender][collateral].lastUpdate = block.timestamp;
        
        // Update total deposited
        info.totalDeposited += amount;
        
        emit CollateralDeposited(msg.sender, collateral, amount);
    }
    
    /**
     * @notice Mint EMAD against deposited collateral
     * @param collateral Collateral to use
     * @param emadAmount Amount of EMAD to mint
     */
    function mintEMAD(
        address collateral,
        uint256 emadAmount
    ) external nonReentrant notPaused onlyAcceptedCollateral(collateral) {
        if (emadAmount == 0) revert Errors.InvalidAmount();
        if (totalDebt + emadAmount > debtCeiling) revert Errors.DebtCeilingExceeded();
        
        Position storage position = positions[msg.sender][collateral];
        CollateralInfo memory info = collateralInfo[collateral];
        
        // Calculate fee
        uint256 fee = (emadAmount * mintFee) / PERCENTAGE_BASE;
        uint256 totalMint = emadAmount + fee;
        
        // Update debt
        position.debtAmount += totalMint;
        totalDebt += totalMint;
        
        // Check collateral ratio
        if (!_isSafePosition(position, info)) revert Errors.UnsafePosition();
        
        // Mint EMAD to user
        EMAD.mint(msg.sender, emadAmount);
        
        // Mint fee to treasury
        if (fee > 0) {
            EMAD.mint(treasury, fee);
            accumulatedFees += fee;
        }
        
        position.lastUpdate = block.timestamp;
        
        emit EMADMinted(msg.sender, collateral, emadAmount);
    }
    
    /**
     * @notice Burn EMAD to reduce debt
     * @param collateral Collateral position to reduce
     * @param emadAmount Amount of EMAD to burn
     */
    function burnEMAD(
        address collateral,
        uint256 emadAmount
    ) external nonReentrant notPaused {
        if (emadAmount == 0) revert Errors.InvalidAmount();
        
        Position storage position = positions[msg.sender][collateral];
        if (position.debtAmount == 0) revert Errors.NoDebt();
        
        uint256 burnAmount = emadAmount > position.debtAmount ? position.debtAmount : emadAmount;
        
        // Burn EMAD from user
        EMAD.burn(burnAmount);
        
        // Update debt
        position.debtAmount -= burnAmount;
        totalDebt -= burnAmount;
        position.lastUpdate = block.timestamp;
        
        emit EMADBurned(msg.sender, collateral, burnAmount);
    }
    
    /**
     * @notice Withdraw collateral after burning debt
     * @param collateral Collateral to withdraw
     * @param amount Amount to withdraw
     */
    function withdrawCollateral(
        address collateral,
        uint256 amount
    ) external nonReentrant notPaused {
        if (amount == 0) revert Errors.InvalidAmount();
        
        Position storage position = positions[msg.sender][collateral];
        if (position.collateralAmount < amount) revert Errors.InsufficientCollateral();
        
        // Update position
        position.collateralAmount -= amount;
        
        // Check position is still safe if debt exists
        if (position.debtAmount > 0) {
            CollateralInfo memory info = collateralInfo[collateral];
            if (!_isSafePosition(position, info)) revert Errors.UnsafePosition();
        }
        
        // Update total deposited
        collateralInfo[collateral].totalDeposited -= amount;
        
        // Transfer collateral to user
        IERC20(collateral).safeTransfer(msg.sender, amount);
        
        position.lastUpdate = block.timestamp;
        
        emit CollateralWithdrawn(msg.sender, collateral, amount);
    }
    
    /**
     * @notice Liquidate unsafe position
     * @param user User to liquidate
     * @param collateral Collateral type
     * @param debtToCover Amount of debt to cover
     */
    function liquidate(
        address user,
        address collateral,
        uint256 debtToCover
    ) external nonReentrant notPaused {
        Position storage position = positions[user][collateral];
        CollateralInfo memory info = collateralInfo[collateral];
        
        // Check if position is liquidatable
        if (_isSafePosition(position, info)) revert Errors.PositionSafe();
        
        uint256 maxDebtToCover = (position.debtAmount * 50) / 100; // Max 50% in one liquidation
        if (debtToCover > maxDebtToCover) {
            debtToCover = maxDebtToCover;
        }
        
        // Calculate collateral to seize (with penalty)
        uint256 collateralPrice = info.priceFeed.getPrice();
        uint256 collateralToSeize = (debtToCover * PRECISION * (PERCENTAGE_BASE + LIQUIDATION_PENALTY)) 
            / (collateralPrice * PERCENTAGE_BASE);
        
        // Liquidator burns EMAD
        EMAD.burn(debtToCover);
        
        // Update positions
        position.debtAmount -= debtToCover;
        position.collateralAmount -= collateralToSeize;
        totalDebt -= debtToCover;
        
        // Transfer collateral to liquidator (with discount)
        uint256 liquidatorReward = (collateralToSeize * (PERCENTAGE_BASE - LIQUIDATION_DISCOUNT)) / PERCENTAGE_BASE;
        IERC20(collateral).safeTransfer(msg.sender, liquidatorReward);
        
        // Send remaining to treasury
        uint256 treasuryAmount = collateralToSeize - liquidatorReward;
        if (treasuryAmount > 0) {
            IERC20(collateral).safeTransfer(treasury, treasuryAmount);
        }
        
        emit Liquidated(user, msg.sender, collateral, debtToCover);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get user's collateral ratio
     */
    function getCollateralRatio(
        address user,
        address collateral
    ) external view returns (uint256) {
        Position memory position = positions[user][collateral];
        if (position.debtAmount == 0) return type(uint256).max;
        
        CollateralInfo memory info = collateralInfo[collateral];
        uint256 collateralValue = position.collateralAmount * info.priceFeed.getPrice() / PRECISION;
        
        return (collateralValue * PERCENTAGE_BASE) / position.debtAmount;
    }
    
    /**
     * @notice Check if position is safe
     */
    function _isSafePosition(
        Position memory position,
        CollateralInfo memory info
    ) private view returns (bool) {
        if (position.debtAmount == 0) return true;
        
        uint256 collateralValue = position.collateralAmount * info.priceFeed.getPrice() / PRECISION;
        uint256 requiredCollateral = (position.debtAmount * info.collateralRatio) / PERCENTAGE_BASE;
        
        return collateralValue >= requiredCollateral;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Add new collateral type
     */
    function addCollateral(
        address collateral,
        uint256 collateralRatio,
        uint256 liquidationRatio,
        uint256 stabilityFee,
        address oracle,
        uint256 cap
    ) external onlyOwner {
        if (collateral == address(0) || oracle == address(0)) revert Errors.ZeroAddress();
        if (collateralRatio < MIN_COLLATERAL_RATIO) revert Errors.InvalidRatio();
        if (liquidationRatio >= collateralRatio) revert Errors.InvalidRatio();
        
        collateralInfo[collateral] = CollateralInfo({
            accepted: true,
            collateralRatio: collateralRatio,
            liquidationRatio: liquidationRatio,
            stabilityFee: stabilityFee,
            priceFeed: IOracle(oracle),
            cap: cap,
            totalDeposited: 0
        });
        
        collateralTokens.push(collateral);
        
        emit CollateralAdded(collateral, collateralRatio, oracle);
    }
    
    /**
     * @notice Update collateral parameters
     */
    function updateCollateral(
        address collateral,
        uint256 newRatio,
        uint256 newCap
    ) external onlyOwner {
        CollateralInfo storage info = collateralInfo[collateral];
        if (!info.accepted) revert Errors.InvalidCollateral();
        
        info.collateralRatio = newRatio;
        info.cap = newCap;
        
        emit CollateralUpdated(collateral, newRatio);
    }
    
    /**
     * @notice Emergency pause
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    /**
     * @notice Update debt ceiling
     */
    function updateDebtCeiling(uint256 newCeiling) external onlyOwner {
        debtCeiling = newCeiling;
    }
    
    /**
     * @notice Collect accumulated fees
     */
    function collectFees() external {
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        
        emit FeesCollected(fees);
    }
}