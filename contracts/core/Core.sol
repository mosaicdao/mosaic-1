pragma solidity ^0.5.0;

// Copyright 2019 OpenST Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../consensus/ConsensusModule.sol";
import "../reputation/ReputationI.sol";
import "../version/MosaicVersion.sol";

contract Core is ConsensusModule, MosaicVersion {

    using SafeMath for uint256;

    /* Enum and structs */

    /** Enum of Core state machine */
    enum Status {
        // core accepts initial set of validators
        creation,
        // core has an open kernel without precommitment to a proposal
        opened,
        // core has precommitted to to a proposal for the open kernel
        precommitted,
        // core has failed to get a proposal committed when challenged for being halted
        halted,
        // precommitted proposal is rejected by consensus committee
        corrupted
    }

    /** The kernel of a meta-block header */
    struct Kernel {
        /** The height of the metablock in the chain */
        uint256 height;
        /** Hash of the metablock's parent */
        bytes32 parent;
        /** Added validators */
        address[] updatedValidators;
        /** Removed validators */
        uint256[] updatedReputation;
        /** Gas target to close the metablock */
        uint256 gasTarget;
        /** Gas price fixed for this metablock */
        uint256 gasPrice;
    }

    struct Transition {
        /** Kernel Hash */
        bytes32 KernelHash;
        /** Observation of the origin chain */
        bytes32 originObservation;
        /** Dynasty number of the metablockchain */
        uint256 dynasty;
        /** Accumulated gas on the metablockchain */
        uint256 accumulatedGas;
        /** Committee lock is the hash of the accumulated transaction root */
        bytes32 committeeLock;
    }

    struct VoteMessage {
        /** Transition hash */
        bytes32 transitionHash;
        /** Source block hash */
        bytes32 source;
        /** Target block hash */
        bytes32 target;
        /** Source block height */
        uint256 sourceBlockHeight;
        /** Target block height */
        uint256 targetBlockHeight;
    }

    struct VoteCount {
        /** Kernel height for proposed metablock */
        uint256 height;
        /** Transition dynasty number for proposed metablock */
        uint256 dynasty;
        /** Vote count for the proposal */
        uint256 count;
    }

    /* Storage */

    /** EIP-712 domain separator name for Core */
    string public constant DOMAIN_SEPARATOR_NAME = "Mosaic-Core";

    /** EIP-712 domain separator for Core */
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /** EIP-712 type hash for Kernel. */
    bytes32 public constant KERNEL_TYPEHASH = keccak256(
        "Kernel(uint256 height,bytes32 parent,address[] updatedValidators,uint256[] updatedReputation,uint256 gasTarget,uint256 gasPrice)"
    );

    /** EIP-712 type hash for a Transition. */
    bytes32 public constant TRANSITION_TYPEHASH = keccak256(
        "Transition(bytes32 kernelHash,bytes32 originObservation,uint256 dynasty,uint256 accumulatedGas,bytes32 committeeLock)"
    );

    /** EIP-712 type hash for a Vote Message */
    bytes32 public constant VOTE_MESSAGE_TYPEHASH = keccak256(
        "VoteMessage(bytes32 transitionHash,bytes32 source,bytes32 target,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );

    /** Sentinel pointer for marking end of linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);

    /** Sentinel pointer for marking end of linked-list of proposals */
    bytes32 public constant SENTINEL_PROPOSALS = bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    /** Maximum future end height, set for all active validators */
    uint256 public constant MAX_FUTURE_END_HEIGHT = uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    /** Maximum validators that can join or logout in one metablock */
    uint256 public constant MAX_DELTA_VALIDATORS = uint256(10);

    /**
     * Define a super-majority fraction used for reaching consensus;
     */
    uint256 public constant CORE_SUPER_MAJORITY_NUMERATOR = uint256(2);
    uint256 public constant CORE_SUPER_MAJORITY_DENOMINATOR = uint256(3);

    /** For open metablocks the voting window is reset to future infinity */
    uint256 public constant CORE_OPEN_VOTES_WINDOW = uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    /** Closing window for reporting last votes on precommitment */
    uint256 public constant CORE_LAST_VOTES_WINDOW = uint256(3);

    /** Domain separator */
    bytes32 public domainSeparator;

    /** Chain Id of the meta-blockchain */
    uint256 public chainId;

    /** Core status */
    Status public coreStatus;

    /** Epoch length */
    uint256 public epochLength;

    /** Validators assigned to this core with their end height registered
     * zero - not registered to this core
     * MAX_FUTURE_END_HEIGHT - for active validators
     * less than MAX_FUTURE_END_HEIGHT - for logged out validators
     */
    mapping(address => uint256) public validators;

    /** Linked list of validators who will join in the next metablock */
    mapping(address => address) public joinedValidators;

    /** Linked list of validators who have logged out */
    mapping(address => address) public loggedOutValidators;

    /** Validator count in core */
    uint256 public countValidators;

    /** Validator minimum count required set by consensus */
    uint256 public minimumValidatorCount;

    /** Join limit for validators */
    uint256 public joinLimit;

    /** Quorum needed for valid proposal */
    uint256 public quorum;

    /** Count of join messages */
    uint256 public countJoinMessages;

    /** Count of log out messages */
    uint256 public countLogOutMessages;

    /** Reputation contract */
    ReputationI public reputation;

    /** Open kernel */
    Kernel public openKernel;

    /** Open kernel hash */
    bytes32 public openKernelHash;

    /** Closed transition object */
    Transition public closedTransition;

    /** Sealing vote message */
    VoteMessage public sealedVoteMessage;

    /** Map kernel height to linked list of proposals */
    mapping(uint256 => mapping(bytes32 => bytes32)) public proposals;

    /** Map proposal hash to VoteCount struct */
    mapping(bytes32 => VoteCount) public voteCounts;

    /** Map validator to proposal hash */
    mapping(address => bytes32) public votes;

    /** Precommitment to a proposal */
    bytes32 public precommit;

    /** Precommitment closure block height */
    uint256 public precommitClosureBlockHeight;

    /* Modifiers */

    modifier duringCreation()
    {
        require(coreStatus == Status.creation,
            "The core must be under creation.");
        _;
    }

    modifier whileRunning()
    {
        require(coreStatus == Status.opened ||
            coreStatus == Status.precommitted,
            "The core must be running.");
        _;
    }

    modifier whileMetablockOpen()
    {
        require(coreStatus == Status.opened,
            "The core must have an open metablock kernel.");
        _;
    }

    modifier whileMetablockPrecommitted()
    {
        require(coreStatus == Status.precommitted,
            "The core must be precommitted.");
        _;
    }

    modifier duringPrecommitmentWindow()
    {
        require(block.number <= precommitClosureBlockHeight,
            "The precommitment window must be open.");
        _;
    }

    /* External and public functions */

    constructor(
        uint256 _chainId,
        uint256 _epochLength,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _gasPrice,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        ConsensusModule(msg.sender) // Core is constructed by Consenus
        public
    {
        // note: consider adding requirement checks
        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                DOMAIN_SEPARATOR_NAME,
                DOMAIN_SEPARATOR_VERSION,
                _chainId,
                address(this)
            )
        );

        coreStatus = Status.creation;

        epochLength = _epochLength;

        reputation = consensus.reputation();

        (minimumValidatorCount, joinLimit) = consensus.coreValidatorThresholds();

        openKernel.height = _height;
        openKernel.parent = _parent;
        openKernel.gasTarget = _gasTarget;
        openKernel.gasPrice = _gasPrice;

        openKernelHash = hashKernel(
            openKernel.height,
            openKernel.parent,
            openKernel.updatedValidators,
            openKernel.updatedReputation,
            openKernel.gasTarget,
            openKernel.gasPrice
        );

        closedTransition.dynasty = _dynasty;
        closedTransition.accumulatedGas = _accumulatedGas;

        sealedVoteMessage.source = _source;
        sealedVoteMessage.sourceBlockHeight = _sourceBlockHeight;

        newProposalSet();
    }

    /**
     * Propose transition object and vote message from seal
     * for the open kernel.
     */
    function proposeMetablock(
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        external
        whileMetablockOpen
    {
        require(_kernelHash == openKernelHash,
            "A metablock can only be proposed for the open Kernel in this core.");
        require(_originObservation != bytes32(0),
            "Origin observation cannot be null.");
        require(_dynasty > closedTransition.dynasty,
            "Dynasty must strictly increase.");
        require(_accumulatedGas > closedTransition.accumulatedGas,
            "Accumulated gas must strictly increase.");
        require(_committeeLock != bytes32(0),
            "Committee lock cannot be null.");
        require(_source != bytes32(0),
            "Source blockhash must not be null.");
        // note: is this necessary?
        require(_source != sealedVoteMessage.source,
            "Source blockhash cannot equal sealed source blockhash.");
        require(_sourceBlockHeight > sealedVoteMessage.sourceBlockHeight,
            "Source block height must strictly increase.");
        require((_sourceBlockHeight % epochLength) == 0,
            "Source block height must be a checkpoint.");
        require(_targetBlockHeight == _sourceBlockHeight.add(epochLength),
            "Target block height must equal source block height plus one.");

        bytes32 transitionHash = hashTransition(
            _kernelHash,
            _originObservation,
            _dynasty,
            _accumulatedGas,
            _committeeLock
        );

        bytes32 proposal = hashVoteMessage(
            transitionHash,
            _source,
            _target,
            _sourceBlockHeight,
            _targetBlockHeight
        );

        // insert proposal, reverts if proposal already inserted
        insertProposal(_dynasty, proposal);
    }

    function registerVote(
        bytes32 _proposal,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        external
        duringPrecommitmentWindow
    {
        require(_proposal != bytes32(0),
            "Proposal can not be null.");
        if (precommit != bytes32(0)) {
            require(_proposal == precommit,
                "Core has precommitted, only votes for precommitment are relevant.");
        }

        uint256 height = openKernel.height;
        require(proposals[height][_proposal] != bytes32(0),
            "Proposal must be registered at open metablock height.");
        address validator = ecrecover(_proposal, _v, _r, _s);
        require(validators[validator] > height,
            "Validator must be registered in this core.");
        require(reputation.isActive(validator),
            "Validator must be active.");

        bytes32 castVote = votes[validator];
        require(castVote != _proposal,
            "Vote has already been cast.");
        VoteCount storage castVoteCount = voteCounts[castVote];
        VoteCount storage registerVoteCount = voteCounts[_proposal];
        if (castVoteCount.height == height) {
            require(castVoteCount.dynasty < registerVoteCount.dynasty,
                "For a given metablock height, the vote can only be recast for higher dynasty numbers.");
            castVoteCount.count = castVoteCount.count.sub(1);
        }
        votes[validator] = _proposal;
        registerVoteCount.count = registerVoteCount.count.add(1);
        if (registerVoteCount.count >= quorum) {
            registerPrecommit(_proposal);
        }
    }

    function openMetablock(
        uint256 _gasTarget,
        uint256 _gasPrice
    )
        external
        onlyConsensus
        whileMetablockPrecommitted
    {
        assert(precommit != bytes32(0));

        openKernel.height = openKernel.height.add(1);
        openKernel.parent = precommit;
        openKernel.gasTarget = _gasTarget;
        openKernel.gasPrice = _gasPrice;

        openKernelHash = hashKernel(
            openKernel.height,
            openKernel.parent,
            openKernel.updatedValidators,
            openKernel.updatedReputation,
            openKernel.gasTarget,
            openKernel.gasPrice
        );
    }

    /**
     * remove vote can be called by consensus when a validator
     * is slashed, to retro-actively remove the vote from the current open metablock
     */
    function removeVote(
        address _validator
    )
        external
        onlyConsensus
        whileRunning
    {
        uint256 height = openKernel.height;
        bytes32 castVote = votes[_validator];
        VoteCount storage castVoteCount = voteCounts[castVote];
        if (castVoteCount.height == height) {
            delete votes[_validator];
            castVoteCount.count = castVoteCount.count.sub(1);
        }
    }

    function joinDuringCreation(address _validator)
        external
        onlyConsensus
        duringCreation
    {
        insertValidator(_validator);
        if (countValidators >= minimumValidatorCount) {
            quorum = calculateQuorum(countValidators);
            precommitClosureBlockHeight = CORE_OPEN_VOTES_WINDOW;
            coreStatus = Status.opened;
        }
    }

    function join(address _validator)
        external
        onlyConsensus
        whileRunning
    {
        require(validators[_validator] == 0,
            "Validator must not have already joined the core.");
        require(joinedValidators[_validator] == address(0),
            "Validator cannot join twice.");
        require(_validator != SENTINEL_VALIDATORS,
            "Validator must not be sentinel address for validators.");
        require(countJoinMessages < MAX_DELTA_VALIDATORS,
            "Maximum number of validators that can join in one metablock is reached.");
        joinedValidators[_validator] = joinedValidators[SENTINEL_VALIDATORS];
        joinedValidators[SENTINEL_VALIDATORS] = _validator;
        countJoinMessages = countJoinMessages.add(1);
    }

    function logout(address _validator)
        external
        onlyConsensus
        whileRunning
    {
        require(validators[_validator] > openKernel.height.add(1),
            "Validator cannot already have logged out.");
        require(loggedOutValidators[_validator] == address(0),
            "Validator cannot log out twice.");
        require(_validator != SENTINEL_VALIDATORS,
            "Validator must not be sentinel address for validators.");
        require(countLogOutMessages < MAX_DELTA_VALIDATORS,
            "Maximum number of validators that can log out in one metablock is reached.");
        loggedOutValidators[_validator] = loggedOutValidators[SENTINEL_VALIDATORS];
        loggedOutValidators[SENTINEL_VALIDATORS] = _validator;
        countLogOutMessages = countLogOutMessages.add(1);
    }

    function calculateQuorum(uint256 _count)
        public
        pure
        returns (uint256 quorum_)
    {
        quorum_ = _count * CORE_SUPER_MAJORITY_NUMERATOR /
            CORE_SUPER_MAJORITY_DENOMINATOR;
    }

    /**
     * @notice Takes the parameters of an transition object and returns the
     *         typed hash of it.
     *
     * @param _kernelHash Kernel hash
     * @param _originObservation Observation of the origin chain.
     * @param _dynasty The dynasty number where the meta-block closes
     *                 on the auxiliary chain.
     * @param _accumulatedGas The total consumed gas on auxiliary within this
     *                        meta-block.
     * @param _committeeLock The committee lock that hashes the transaction
     *                       root on the auxiliary chain.
     * @return hash_ The hash of this transition object.
     */
    function hashTransition(
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock
    )
        public
        view
        returns (bytes32 hash_)
    {
        bytes32 typedTransitionHash = keccak256(
            abi.encode(
                TRANSITION_TYPEHASH,
                _kernelHash,
                _originObservation,
                _dynasty,
                _accumulatedGas,
                _committeeLock
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedTransitionHash
            )
        );
    }

    function hashVoteMessage(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        public
        view
        returns (bytes32 hash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                VOTE_MESSAGE_TYPEHASH,
                _transitionHash,
                _source,
                _target,
                _sourceBlockHeight,
                _targetBlockHeight
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedVoteMessageHash
            )
        );
    }


    /* Internal and private functions */

    /**
     * precommit to a given proposal and lock core validators
     * to associated responsability
     */
    function registerPrecommit(bytes32 _proposal)
        internal
    {
        require(precommit == bytes32(0) ||
            precommit == _proposal,
            "Once locked, precommit cannot be changed.");
        if (coreStatus == Status.opened) {
            coreStatus = Status.precommitted;
            precommit = _proposal;
            precommitClosureBlockHeight = block.number.add(CORE_LAST_VOTES_WINDOW);
            consensus.registerPrecommit(_proposal);
        }
    }

    /**
     * start new linked list for proposals
     */
    function newProposalSet()
        internal
    {
        uint256 height = openKernel.height;
        require(proposals[height][SENTINEL_PROPOSALS] == bytes32(0),
            "Proposal set has already been initialised at this height.");
        proposals[height][SENTINEL_PROPOSALS] = SENTINEL_PROPOSALS;
    }

    /**
     * insert proposal
     */
    function insertProposal(
        uint256 _dynasty,
        bytes32 _proposal
    )
        internal
    {
        uint256 height = openKernel.height;
        VoteCount storage voteCount = voteCounts[_proposal];

        // note: redundant because we always calculate the proposal hash
        require(_proposal != bytes32(0),
            "Proposal must not be null.");
        require(proposals[height][_proposal] == bytes32(0),
            "Proposal can only be inserted once.");
        require(_proposal != SENTINEL_PROPOSALS,
            "Proposal must not be sentinel for proposals.");

        // vote registered for open kernel
        voteCount.height = height;
        // register dynasty of transition
        voteCount.dynasty = _dynasty;
        // vote count is zero
        voteCount.count = 0;

        proposals[height][_proposal] = proposals[height][SENTINEL_PROPOSALS];
        proposals[height][SENTINEL_PROPOSALS] = _proposal;
    }

    /**
     * clean proposals
     * note: improve logic, to be done partially in case too much gas needed
     *       double-check if logic is correct
     */
    function cleanProposals(uint256 _height)
        internal
    {
        require(_height < openKernel.height,
            "Only proposals of older kernels can be cleaned out.");
        bytes32 currentProposal = proposals[_height][SENTINEL_PROPOSALS];
        bytes32 deleteProposal = SENTINEL_PROPOSALS;
        require(currentProposal != bytes32(0),
            "There are no proposals to clear out.");
        while (currentProposal != SENTINEL_PROPOSALS) {
            delete proposals[_height][deleteProposal];
            delete voteCounts[deleteProposal];
            deleteProposal = currentProposal;
            currentProposal = proposals[_height][currentProposal];
        }
        delete proposals[_height][deleteProposal];
        delete voteCounts[deleteProposal];
    }

    /**
     * insert validator in linked-list
     */
    function insertValidator(address _validator)
        internal
    {
        require(_validator != address(0),
            "Validator must not be null address.");
        require(validators[_validator] == 0,
            "Validator must not already be part of this core.");
        validators[_validator] = MAX_FUTURE_END_HEIGHT;
        countValidators = countValidators.add(1);
    }

    // /**
    //  * remove validator from linked-list
    //  */
    // function removeValidator(address _validator, address _prevValidator)
    //     internal
    // {
    //     require(_validator != address(0) &&
    //         _validator != SENTINEL_VALIDATORS,
    //         "Validator null or sentinel address cannot be removed.");
    //     require(_validator == validators[_prevValidator],
    //         "Invalid validator-pair provided to remove validator from core.");
    //     validators[_prevValidator] = validators[_validator];
    //     delete validators[_validator];
    // }

    /**
     * @notice Takes the parameters of a kernel object and returns the
     *         typed hash of it.
     *
     * @param _height The height of meta-block.
     * @param _parent The hash of this block's parent.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock
     * @param _gasPrice The gas price for this metablock
     *
     * @return hash_ The hash of kernel.
     */
    function hashKernel(
        uint256 _height,
        bytes32 _parent,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation,
        uint256 _gasTarget,
        uint256 _gasPrice
    )
        internal
        view
        returns (bytes32 hash_)
    {
        bytes32 typedKernelHash = keccak256(
            abi.encode(
                KERNEL_TYPEHASH,
                _height,
                _parent,
                _updatedValidators,
                _updatedReputation,
                _gasTarget,
                _gasPrice
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedKernelHash
            )
        );
    }
}
