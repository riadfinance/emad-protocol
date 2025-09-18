// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IEMAD.sol";
import "./interfaces/IOracle.sol";
import "./libraries/Errors.sol";
import "./libraries/Math.sol";

/**
 * @title EMADMinter
 * @author RIAD Finance
 * @notice Controls minting and burning of E-MAD with advanced features
 * @dev Implements dynamic fees, rate limiting, and cross-chain minting
 */
contract EMADMinter is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using MathUtils for uint256;
    
    // ============ Roles ============
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    
    // ============ State Variables ============
    
    IEMAD public immutable EMAD;
    address public immutable vault;
    
    // Minting parameters
    struct MintParams {
        uint256 dailyLimit;           // Max mint per day
        uint256 hourlyLimit;          // Max mint per hour
        uint256 perTransactionLimit;  // Max per single mint
        uint256 minMintAmount;        // Minimum mint amount
        uint256 mintFee;              // Fee in basis points
        uint256 dynamicFeeEnabled;    // 1 = enabled, 0 = disabled
    }
    
    MintParams public mintParams;
    
    // Burning parameters
    struct BurnParams {
        uint256 dailyLimit;           // Max burn per day
        uint256 hourlyLimit;          // Max burn per hour
        uint256 perTransactionLimit;  // Max per single burn
        uint256 minBurnAmount;        // Minimum burn amount
        uint256 burnFee;              // Fee in basis points
        uint256 cooldownPeriod;       // Time between burns
    }
    
    BurnParams public burnParams;
    
    // Rate limiting
    struct RateLimit {
        uint256 dailyMinted;
        uint256 hourlyMinted;
        uint256 dailyBurned;
        uint256 hourlyBurned;
        uint256 lastDailyReset;
        uint256 lastHourlyReset;
    }
    
    mapping(address => RateLimit) public userLimits;
    RateLimit public globalLimits;
    
    // User mint/burn history
    struct UserHistory {
        uint256 totalMinted;
        uint256 totalBurned;
        uint256 lastMintTime;
        uint256 lastBurnTime;
        uint256 mintCount;
        uint256 burnCount;
    }
    
    mapping(address => UserHistory) public userHistory;
    
    // Whitelisting
    mapping(address => bool) public whitelistedMinters;
    mapping(address => bool) public blacklisted;
    
    // Cross-chain minting
    mapping(uint16 => address) public crossChainMinters; // chainId => minter address
    mapping(bytes32 => bool) public processedCrossChainMints;
    
    // Dynamic fee calculation
    uint256 public constant PRECISION = 1e18;
    uint256 public constant FEE_PRECISION = 10000;
    uint256 public targetSupply;
    uint256 public supplyThresholdHigh = 10200; // 102%
    uint256 public supplyThresholdLow = 9800;  // 98%
    
    // Emergency controls
    bool public emergencyMintPaused;
    bool public emergencyBurnPaused;
    uint256 public emergencyWithdrawDelay = 3 days;
    
    // Treasury
    address public treasury;
    uint256 public accumulatedFees;
    
    // Oracle
    IOracle public priceOracle;
    uint256 public constant PRICE_PRECISION = 1e8;
    uint256 public maxPriceDeviation = 300; // 3%
    
    // ============ Events ============
    
    event Minted(address indexed to, uint256 amount, uint256 fee);
    event Burned(address indexed from, uint256 amount, uint256 fee);
    event CrossChainMint(uint16 indexed chainId, address indexed to, uint256 amount);
    event CrossChainBurn(uint16 indexed chainId, address indexed from, uint256 amount);
    event WhitelistUpdated(address indexed user, bool status);
    event BlacklistUpdated(address indexed user, bool status);
    event ParametersUpdated(string paramType);
    event EmergencyPause(bool mintPaused, bool burnPaused);
    event FeesCollected(uint256 amount);
    event DynamicFeeApplied(uint256 baseFee, uint256 dynamicFee);
    
    // ============ Modifiers ============
    
    modifier notBlacklisted() {
        if (blacklisted[msg.sender]) revert Errors.Blacklisted();
        _;
    }
    
    modifier onlyWhitelistedOrPublic() {
        if (mintParams.dynamicFeeEnabled == 1 && !whitelistedMinters[msg.sender]) {
            revert Errors.NotWhitelisted();
        }
        _;
    }
    
    modifier checkMintLimits(uint256 amount) {
        _checkAndUpdateLimits(msg.sender, amount, true);
        _;
    }
    
    modifier checkBurnLimits(uint256 amount) {
        _checkAndUpdateLimits(msg.sender, amount, false);
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _emad,
        address _vault,
        address _treasury,
        address _priceOracle
    ) {
        if (_emad == address(0) || _vault == address(0) || _treasury == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        EMAD = IEMAD(_emad);
        vault = _vault;
        treasury = _treasury;
        priceOracle = IOracle(_priceOracle);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, _vault);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        
        // Initialize parameters
        mintParams = MintParams({
            dailyLimit: 10_000_000 * 10**18,
            hourlyLimit: 1_000_000 * 10**18,
            perTransactionLimit: 100_000 * 10**18,
            minMintAmount: 100 * 10**18,
            mintFee: 30, // 0.3%
            dynamicFeeEnabled: 1
        });
        
        burnParams = BurnParams({
            dailyLimit: 10_000_000 * 10**18,
            hourlyLimit: 1_000_000 * 10**18,
            perTransactionLimit: 100_000 * 10**18,
            minBurnAmount: 100 * 10**18,
            burnFee: 30, // 0.3%
            cooldownPeriod: 1 hours
        });
        
        targetSupply = 100_000_000 * 10**18; // 100M target
    }
    
    // ============ Core Minting Functions ============
    
    /**
     * @notice Mint E-MAD tokens
     * @param to Address to mint to
     * @param amount Amount to mint
     * @return mintedAmount Actual amount minted after fees
     */
    function mint(
        address to,
        uint256 amount
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        notBlacklisted
        onlyWhitelistedOrPublic
        checkMintLimits(amount)
        returns (uint256 mintedAmount) 
    {
        if (emergencyMintPaused) revert Errors.EmergencyPause();
        if (amount < mintParams.minMintAmount) revert Errors.AmountTooSmall();
        if (amount > mintParams.perTransactionLimit) revert Errors.AmountTooLarge();
        
        // Check price deviation
        _checkPriceDeviation();
        
        // Calculate fees
        uint256 fee = _calculateMintFee(amount);
        mintedAmount = amount - fee;
        
        // Update history
        userHistory[msg.sender].totalMinted += amount;
        userHistory[msg.sender].lastMintTime = block.timestamp;
        userHistory[msg.sender].mintCount++;
        
        // Mint tokens
        EMAD.mint(to, mintedAmount);
        
        // Mint fee to treasury
        if (fee > 0) {
            EMAD.mint(treasury, fee);
            accumulatedFees += fee;
        }
        
        emit Minted(to, mintedAmount, fee);
        
        return mintedAmount;
    }
    
    /**
     * @notice Burn E-MAD tokens
     * @param amount Amount to burn
     * @return burnedAmount Actual amount burned after fees
     */
    function burn(
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        notBlacklisted
        checkBurnLimits(amount)
        returns (uint256 burnedAmount)
    {
        if (emergencyBurnPaused) revert Errors.EmergencyPause();
        if (amount < burnParams.minBurnAmount) revert Errors.AmountTooSmall();
        if (amount > burnParams.perTransactionLimit) revert Errors.AmountTooLarge();
        
        // Check cooldown
        if (block.timestamp < userHistory[msg.sender].lastBurnTime + burnParams.cooldownPeriod) {
            revert Errors.CooldownActive();
        }
        
        // Calculate fees
        uint256 fee = _calculateBurnFee(amount);
        burnedAmount = amount - fee;
        
        // Update history
        userHistory[msg.sender].totalBurned += burnedAmount;
        userHistory[msg.sender].lastBurnTime = block.timestamp;
        userHistory[msg.sender].burnCount++;
        
        // Transfer EMAD from user
        IERC20(address(EMAD)).safeTransferFrom(msg.sender, address(this), amount);
        
        // Burn tokens
        EMAD.burn(burnedAmount);
        
        // Send fee to treasury
        if (fee > 0) {
            IERC20(address(EMAD)).safeTransfer(treasury, fee);
            accumulatedFees += fee;
        }
        
        emit Burned(msg.sender, burnedAmount, fee);
        
        return burnedAmount;
    }
    
    /**
     * @notice Cross-chain mint request
     * @param chainId Destination chain ID
     * @param to Recipient address
     * @param amount Amount to mint
     * @param nonce Unique nonce for request
     */
    function crossChainMint(
        uint16 chainId,
        address to,
        uint256 amount,
        uint256 nonce
    ) external onlyRole(MINTER_ROLE) {
        bytes32 mintHash = keccak256(abi.encodePacked(chainId, to, amount, nonce));
        
        if (processedCrossChainMints[mintHash]) revert Errors.AlreadyProcessed();
        
        processedCrossChainMints[mintHash] = true;
        
        EMAD.mint(to, amount);
        
        emit CrossChainMint(chainId, to, amount);
    }
    
    // ============ Fee Calculation ============
    
    /**
     * @notice Calculate dynamic mint fee based on supply
     */
    function _calculateMintFee(uint256 amount) private view returns (uint256) {
        uint256 baseFee = (amount * mintParams.mintFee) / FEE_PRECISION;
        
        if (mintParams.dynamicFeeEnabled == 0) {
            return baseFee;
        }
        
        uint256 currentSupply = EMAD.totalSupply();
        uint256 supplyRatio = (currentSupply * FEE_PRECISION) / targetSupply;
        
        // Increase fee if above target
        if (supplyRatio > supplyThresholdHigh) {
            uint256 multiplier = ((supplyRatio - FEE_PRECISION) * 2) / 100;
            return baseFee + (baseFee * multiplier) / FEE_PRECISION;
        }
        
        // Decrease fee if below target
        if (supplyRatio < supplyThresholdLow) {
            uint256 discount = ((FEE_PRECISION - supplyRatio) * 50) / 100;
            uint256 reduction = (baseFee * discount) / FEE_PRECISION;
            return baseFee > reduction ? baseFee - reduction : 0;
        }
        
        return baseFee;
    }
    
    /**
     * @notice Calculate burn fee
     */
    function _calculateBurnFee(uint256 amount) private view returns (uint256) {
        return (amount * burnParams.burnFee) / FEE_PRECISION;
    }
    
    // ============ Rate Limiting ============
    
    /**
     * @notice Check and update rate limits
     */
    function _checkAndUpdateLimits(
        address user,
        uint256 amount,
        bool isMint
    ) private {
        // Reset daily limits if needed
        if (block.timestamp >= globalLimits.lastDailyReset + 1 days) {
            globalLimits.dailyMinted = 0;
            globalLimits.dailyBurned = 0;
            globalLimits.lastDailyReset = block.timestamp;
        }
        
        // Reset hourly limits if needed
        if (block.timestamp >= globalLimits.lastHourlyReset + 1 hours) {
            globalLimits.hourlyMinted = 0;
            globalLimits.hourlyBurned = 0;
            globalLimits.lastHourlyReset = block.timestamp;
        }
        
        // Check and update user limits
        RateLimit storage userLimit = userLimits[user];
        
        if (block.timestamp >= userLimit.lastDailyReset + 1 days) {
            userLimit.dailyMinted = 0;
            userLimit.dailyBurned = 0;
            userLimit.lastDailyReset = block.timestamp;
        }
        
        if (block.timestamp >= userLimit.lastHourlyReset + 1 hours) {
            userLimit.hourlyMinted = 0;
            userLimit.hourlyBurned = 0;
            userLimit.lastHourlyReset = block.timestamp;
        }
        
        if (isMint) {
            // Check global limits
            if (globalLimits.dailyMinted + amount > mintParams.dailyLimit) {
                revert Errors.DailyLimitExceeded();
            }
            if (globalLimits.hourlyMinted + amount > mintParams.hourlyLimit) {
                revert Errors.HourlyLimitExceeded();
            }
            
            // Update limits
            globalLimits.dailyMinted += amount;
            globalLimits.hourlyMinted += amount;
            userLimit.dailyMinted += amount;
            userLimit.hourlyMinted += amount;
        } else {
            // Check burn limits
            if (globalLimits.dailyBurned + amount > burnParams.dailyLimit) {
                revert Errors.DailyLimitExceeded();
            }
            if (globalLimits.hourlyBurned + amount > burnParams.hourlyLimit) {
                revert Errors.HourlyLimitExceeded();
            }
            
            // Update limits
            globalLimits.dailyBurned += amount;
            globalLimits.hourlyBurned += amount;
            userLimit.dailyBurned += amount;
            userLimit.hourlyBurned += amount;
        }
    }
    
    /**
     * @notice Check price deviation from oracle
     */
    function _checkPriceDeviation() private view {
        uint256 price = priceOracle.getPrice();
        uint256 expectedPrice = PRICE_PRECISION; // 1:1 peg
        
        uint256 deviation;
        if (price > expectedPrice) {
            deviation = ((price - expectedPrice) * FEE_PRECISION) / expectedPrice;
        } else {
            deviation = ((expectedPrice - price) * FEE_PRECISION) / expectedPrice;
        }
        
        if (deviation > maxPriceDeviation) {
            revert Errors.PriceDeviationTooHigh();
        }
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update mint parameters
     */
    function updateMintParams(
        uint256 dailyLimit,
        uint256 hourlyLimit,
        uint256 perTransactionLimit,
        uint256 minAmount,
        uint256 fee,
        uint256 dynamicEnabled
    ) external onlyRole(OPERATOR_ROLE) {
        mintParams = MintParams({
            dailyLimit: dailyLimit,
            hourlyLimit: hourlyLimit,
            perTransactionLimit: perTransactionLimit,
            minMintAmount: minAmount,
            mintFee: fee,
            dynamicFeeEnabled: dynamicEnabled
        });
        
        emit ParametersUpdated("MINT");
    }
    
    /**
     * @notice Update burn parameters
     */
    function updateBurnParams(
        uint256 dailyLimit,
        uint256 hourlyLimit,
        uint256 perTransactionLimit,
        uint256 minAmount,
        uint256 fee,
        uint256 cooldown
    ) external onlyRole(OPERATOR_ROLE) {
        burnParams = BurnParams({
            dailyLimit: dailyLimit,
            hourlyLimit: hourlyLimit,
            perTransactionLimit: perTransactionLimit,
            minBurnAmount: minAmount,
            burnFee: fee,
            cooldownPeriod: cooldown
        });
        
        emit ParametersUpdated("BURN");
    }
    
    /**
     * @notice Update whitelist status
     */
    function setWhitelist(address user, bool status) external onlyRole(OPERATOR_ROLE) {
        whitelistedMinters[user] = status;
        emit WhitelistUpdated(user, status);
    }
    
    /**
     * @notice Update blacklist status
     */
    function setBlacklist(address user, bool status) external onlyRole(GUARDIAN_ROLE) {
        blacklisted[user] = status;
        emit BlacklistUpdated(user, status);
    }
    
    /**
     * @notice Emergency pause minting/burning
     */
    function emergencyPause(bool pauseMint, bool pauseBurn) external onlyRole(GUARDIAN_ROLE) {
        emergencyMintPaused = pauseMint;
        emergencyBurnPaused = pauseBurn;
        emit EmergencyPause(pauseMint, pauseBurn);
    }
    
    /**
     * @notice Collect accumulated fees
     */
    function collectFees() external {
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        emit FeesCollected(fees);
    }
    
    /**
     * @notice Update price oracle
     */
    function updateOracle(address newOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newOracle == address(0)) revert Errors.ZeroAddress();
        priceOracle = IOracle(newOracle);
    }
    
    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get current mint fee for amount
     */
    function getMintFee(uint256 amount) external view returns (uint256) {
        return _calculateMintFee(amount);
    }
    
    /**
     * @notice Get current burn fee for amount
     */
    function getBurnFee(uint256 amount) external view returns (uint256) {
        return _calculateBurnFee(amount);
    }
    
    /**
     * @notice Get user's remaining daily mint limit
     */
    function getUserMintLimit(address user) external view returns (uint256) {
        RateLimit memory limit = userLimits[user];
        
        if (block.timestamp >= limit.lastDailyReset + 1 days) {
            return mintParams.dailyLimit;
        }
        
        return mintParams.dailyLimit > limit.dailyMinted 
            ? mintParams.dailyLimit - limit.dailyMinted 
            : 0;
    }
    
    /**
     * @notice Check if user can mint
     */
    function canMint(address user, uint256 amount) external view returns (bool) {
        if (blacklisted[user]) return false;
        if (emergencyMintPaused) return false;
        if (amount < mintParams.minMintAmount) return false;
        if (amount > mintParams.perTransactionLimit) return false;
        
        // Check rate limits
        RateLimit memory limit = userLimits[user];
        if (limit.dailyMinted + amount > mintParams.dailyLimit) return false;
        if (limit.hourlyMinted + amount > mintParams.hourlyLimit) return false;
        
        return true;
    }
}