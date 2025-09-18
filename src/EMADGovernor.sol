// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorPreventLateQuorum.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./libraries/Errors.sol";

/**
 * @title EMADGovernor
 * @author RIAD Finance
 * @notice Governance contract for RIAD protocol
 * @dev Implements on-chain governance with timelock and advanced features
 */
contract EMADGovernor is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    GovernorPreventLateQuorum
{
    // ============ State Variables ============
    
    // Governance token (veRIAD or RIAD)
    IERC20 public immutable governanceToken;
    
    // Proposal types
    enum ProposalType {
        PARAMETER_CHANGE,    // Change protocol parameters
        TREASURY_ALLOCATION, // Allocate treasury funds
        EMERGENCY_ACTION,    // Emergency actions (higher quorum)
        UPGRADE_CONTRACT,    // Contract upgrades
        ADD_COLLATERAL,      // Add new collateral types
        GRANT_ROLE          // Grant roles to addresses
    }
    
    // Proposal metadata
    struct ProposalMetadata {
        ProposalType proposalType;
        string ipfsHash;           // IPFS hash for detailed description
        uint256 createdAt;
        address proposer;
        bool executed;
        bool cancelled;
    }
    
    mapping(uint256 => ProposalMetadata) public proposalMetadata;
    
    // Voting power delegation
    mapping(address => address) public voteDelegation;
    mapping(address => uint256) public delegatedVotingPower;
    
    // Proposal thresholds by type
    mapping(ProposalType => uint256) public proposalThresholds;
    mapping(ProposalType => uint256) public quorumThresholds;
    
    // Veto mechanism
    address public vetoer;
    mapping(uint256 => bool) public vetoed;
    uint256 public constant VETO_PERIOD = 2 days;
    
    // Treasury management
    address public treasury;
    uint256 public treasurySpendLimit = 1_000_000 * 10**18; // Per proposal limit
    mapping(uint256 => uint256) public proposalSpendAmount;
    
    // Incentives
    uint256 public proposalReward = 1000 * 10**18; // Reward for successful proposals
    uint256 public votingReward = 10 * 10**18;     // Reward per vote
    mapping(address => uint256) public unclaimedRewards;
    
    // Reputation system
    mapping(address => uint256) public memberReputation;
    mapping(address => uint256) public successfulProposals;
    mapping(address => uint256) public failedProposals;
    
    // Emergency
    bool public emergencyMode;
    uint256 public emergencyProposalId;
    
    // Stats
    uint256 public totalProposals;
    uint256 public totalSuccessfulProposals;
    uint256 public totalFailedProposals;
    uint256 public totalVotesCast;
    
    // ============ Events ============
    
    event ProposalCreatedWithType(
        uint256 indexed proposalId,
        ProposalType proposalType,
        address indexed proposer,
        string description
    );
    event ProposalVetoed(uint256 indexed proposalId, address indexed vetoer);
    event VoteCastWithReason(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );
    event RewardsDistributed(address indexed recipient, uint256 amount);
    event EmergencyModeActivated(uint256 indexed proposalId);
    event TreasuryAllocation(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event ReputationUpdated(address indexed member, uint256 oldRep, uint256 newRep);
    
    // ============ Modifiers ============
    
    modifier onlyVetoer() {
        if (msg.sender != vetoer) revert Errors.Unauthorized();
        _;
    }
    
    modifier notEmergency() {
        if (emergencyMode) revert Errors.EmergencyMode();
        _;
    }
    
    modifier proposalExists(uint256 proposalId) {
        if (proposalMetadata[proposalId].createdAt == 0) revert Errors.ProposalNotFound();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        IVotes _token,
        TimelockController _timelock,
        address _treasury,
        address _vetoer
    )
        Governor("RIAD Governor")
        GovernorSettings(
            1,              // 1 block voting delay
            50400,          // 1 week voting period (assuming 12s blocks)
            100000 * 10**18 // 100k tokens proposal threshold
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4) // 4% quorum
        GovernorTimelockControl(_timelock)
        GovernorPreventLateQuorum(7200) // Extend 1 day if quorum reached late
    {
        governanceToken = IERC20(address(_token));
        treasury = _treasury;
        vetoer = _vetoer;
        
        // Set default thresholds
        proposalThresholds[ProposalType.PARAMETER_CHANGE] = 100000 * 10**18;
        proposalThresholds[ProposalType.TREASURY_ALLOCATION] = 250000 * 10**18;
        proposalThresholds[ProposalType.EMERGENCY_ACTION] = 500000 * 10**18;
        proposalThresholds[ProposalType.UPGRADE_CONTRACT] = 500000 * 10**18;
        proposalThresholds[ProposalType.ADD_COLLATERAL] = 100000 * 10**18;
        proposalThresholds[ProposalType.GRANT_ROLE] = 250000 * 10**18;
        
        // Set quorum thresholds (in basis points)
        quorumThresholds[ProposalType.PARAMETER_CHANGE] = 400;     // 4%
        quorumThresholds[ProposalType.TREASURY_ALLOCATION] = 500;  // 5%
        quorumThresholds[ProposalType.EMERGENCY_ACTION] = 1000;    // 10%
        quorumThresholds[ProposalType.UPGRADE_CONTRACT] = 1000;    // 10%
        quorumThresholds[ProposalType.ADD_COLLATERAL] = 400;       // 4%
        quorumThresholds[ProposalType.GRANT_ROLE] = 500;          // 5%
    }
    
    // ============ Core Governance Functions ============
    
    /**
     * @notice Create a typed proposal
     */
    function proposeWithType(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalType proposalType,
        string memory ipfsHash
    ) public returns (uint256) {
        // Check proposal threshold for type
        uint256 threshold = proposalThresholds[proposalType];
        if (getVotes(msg.sender, block.number - 1) < threshold) {
            revert Errors.InsufficientVotingPower();
        }
        
        // Special checks for treasury proposals
        if (proposalType == ProposalType.TREASURY_ALLOCATION) {
            uint256 totalValue = 0;
            for (uint256 i = 0; i < values.length; i++) {
                totalValue += values[i];
            }
            if (totalValue > treasurySpendLimit) {
                revert Errors.ExceedsTreasuryLimit();
            }
            proposalSpendAmount[totalProposals] = totalValue;
        }
        
        uint256 proposalId = propose(targets, values, calldatas, description);
        
        // Store metadata
        proposalMetadata[proposalId] = ProposalMetadata({
            proposalType: proposalType,
            ipfsHash: ipfsHash,
            createdAt: block.timestamp,
            proposer: msg.sender,
            executed: false,
            cancelled: false
        });
        
        totalProposals++;
        
        emit ProposalCreatedWithType(proposalId, proposalType, msg.sender, description);
        
        return proposalId;
    }
    
    /**
     * @notice Cast vote with reason
     */
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) public override(Governor) returns (uint256) {
        address voter = msg.sender;
        uint256 weight = getVotes(voter, proposalSnapshot(proposalId));
        
        // Distribute voting rewards
        if (weight > 0) {
            uint256 reward = (votingReward * weight) / (10**18);
            unclaimedRewards[voter] += reward;
        }
        
        totalVotesCast++;
        
        emit VoteCastWithReason(voter, proposalId, support, weight, reason);
        
        return super.castVoteWithReasonAndParams(proposalId, support, reason, params);
    }
    
    /**
     * @notice Execute proposal with additional checks
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(Governor) returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        
        // Check if vetoed
        if (vetoed[proposalId]) {
            revert Errors.ProposalVetoed();
        }
        
        // Update metadata
        proposalMetadata[proposalId].executed = true;
        
        // Update proposer reputation
        address proposer = proposalMetadata[proposalId].proposer;
        successfulProposals[proposer]++;
        _updateReputation(proposer, true);
        
        // Distribute proposal reward
        unclaimedRewards[proposer] += proposalReward;
        
        totalSuccessfulProposals++;
        
        return super.execute(targets, values, calldatas, descriptionHash);
    }
    
    /**
     * @notice Veto a proposal (only vetoer)
     */
    function veto(uint256 proposalId) external onlyVetoer proposalExists(proposalId) {
        ProposalState currentState = state(proposalId);
        
        if (currentState != ProposalState.Pending && 
            currentState != ProposalState.Active &&
            currentState != ProposalState.Succeeded) {
            revert Errors.InvalidProposalState();
        }
        
        // Check veto period
        if (block.timestamp > proposalDeadline(proposalId) + VETO_PERIOD) {
            revert Errors.VetoPeriodExpired();
        }
        
        vetoed[proposalId] = true;
        
        emit ProposalVetoed(proposalId, msg.sender);
    }
    
    /**
     * @notice Emergency proposal execution
     */
    function emergencyPropose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        // Only vetoer or high reputation members can create emergency proposals
        if (msg.sender != vetoer && memberReputation[msg.sender] < 1000) {
            revert Errors.Unauthorized();
        }
        
        uint256 proposalId = proposeWithType(
            targets,
            values,
            calldatas,
            description,
            ProposalType.EMERGENCY_ACTION,
            ""
        );
        
        emergencyMode = true;
        emergencyProposalId = proposalId;
        
        emit EmergencyModeActivated(proposalId);
        
        return proposalId;
    }
    
    // ============ Delegation Functions ============
    
    /**
     * @notice Delegate voting power
     */
    function delegateVotingPower(address delegatee) external {
        address currentDelegate = voteDelegation[msg.sender];
        
        if (currentDelegate != address(0)) {
            delegatedVotingPower[currentDelegate] -= getVotes(msg.sender, block.number - 1);
        }
        
        voteDelegation[msg.sender] = delegatee;
        delegatedVotingPower[delegatee] += getVotes(msg.sender, block.number - 1);
    }
    
    /**
     * @notice Get total voting power including delegations
     */
    function getTotalVotingPower(address account) public view returns (uint256) {
        return getVotes(account, block.number - 1) + delegatedVotingPower[account];
    }
    
    // ============ Reputation System ============
    
    /**
     * @notice Update member reputation
     */
    function _updateReputation(address member, bool success) private {
        uint256 oldRep = memberReputation[member];
        
        if (success) {
            memberReputation[member] += 100; // +100 rep for successful proposal
        } else {
            memberReputation[member] = oldRep > 50 ? oldRep - 50 : 0; // -50 for failed
        }
        
        emit ReputationUpdated(member, oldRep, memberReputation[member]);
    }
    
    /**
     * @notice Get member stats
     */
    function getMemberStats(address member) external view returns (
        uint256 reputation,
        uint256 successful,
        uint256 failed,
        uint256 rewards
    ) {
        return (
            memberReputation[member],
            successfulProposals[member],
            failedProposals[member],
            unclaimedRewards[member]
        );
    }
    
    // ============ Reward Functions ============
    
    /**
     * @notice Claim accumulated rewards
     */
    function claimRewards() external {
        uint256 rewards = unclaimedRewards[msg.sender];
        if (rewards == 0) revert Errors.NoRewards();
        
        unclaimedRewards[msg.sender] = 0;
        
        // Transfer rewards from treasury
        IERC20(governanceToken).transferFrom(treasury, msg.sender, rewards);
        
        emit RewardsDistributed(msg.sender, rewards);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update proposal thresholds
     */
    function updateProposalThreshold(
        ProposalType proposalType,
        uint256 newThreshold
    ) external {
        proposalThresholds[proposalType] = newThreshold;
    }
    
    /**
     * @notice Update quorum thresholds
     */
    function updateQuorumThreshold(
        ProposalType proposalType,
        uint256 newQuorum
    ) external {
        quorumThresholds[proposalType] = newQuorum;
    }
    
    /**
     * @notice Update vetoer
     */
    function updateVetoer(address newVetoer) external onlyGovernance {
        vetoer = newVetoer;
    }
    
    /**
     * @notice Update rewards
     */
    function updateRewards(
        uint256 _proposalReward,
        uint256 _votingReward
    ) external {
        proposalReward = _proposalReward;
        votingReward = _votingReward;
    }
    
    /**
     * @notice Disable emergency mode
     */
    function disableEmergencyMode() external onlyGovernance {
        emergencyMode = false;
        emergencyProposalId = 0;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get proposal details
     */
    function getProposalDetails(uint256 proposalId) 
        external 
        view 
        returns (
            ProposalMetadata memory metadata,
            ProposalState currentState,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        ) 
    {
        metadata = proposalMetadata[proposalId];
        currentState = state(proposalId);
        (forVotes, againstVotes, abstainVotes) = proposalVotes(proposalId);
    }
    
    /**
     * @notice Check if proposal meets quorum
     */
    function meetsQuorum(uint256 proposalId) public view returns (bool) {
        ProposalMetadata memory metadata = proposalMetadata[proposalId];
        uint256 requiredQuorum = quorumThresholds[metadata.proposalType];
        
        (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) = proposalVotes(proposalId);
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        
        return (totalVotes * 10000) >= (totalSupply * requiredQuorum);
    }
    
    /**
     * @notice Get governance statistics
     */
    function getGovernanceStats() external view returns (
        uint256 proposals,
        uint256 successful,
        uint256 failed,
        uint256 votes,
        uint256 activeVoters
    ) {
        return (
            totalProposals,
            totalSuccessfulProposals,
            totalFailedProposals,
            totalVotesCast,
            0 // Would need to track this separately
        );
    }
    
    // ============ Override Functions ============
    
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        if (vetoed[proposalId]) {
            return ProposalState.Canceled;
        }
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function proposalDeadline(uint256 proposalId)
        public
        view
        override(Governor, GovernorPreventLateQuorum)
        returns (uint256)
    {
        return super.proposalDeadline(proposalId);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Required override functions for Governor compatibility
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
    
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
    
    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }
    
    function _tallyUpdated(
        uint256 proposalId
    ) internal override(Governor, GovernorPreventLateQuorum) {
        super._tallyUpdated(proposalId);
    }
}