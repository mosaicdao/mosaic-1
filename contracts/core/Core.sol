pragma solidity >=0.5.0 <0.6.0;

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

import "./CoreI.sol";
import "./CoreStatusEnum.sol";
import "../consensus/ConsensusModule.sol";
import "../validator-set/ValidatorSet.sol";
import "../reputation/ReputationI.sol";
import "../version/MosaicVersion.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

contract Core is MasterCopyNonUpgradable, ConsensusModule, ValidatorSet, MosaicVersion, CoreStatusEnum, CoreI {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    /** Emitted when new metablock is proposed */
    event MetablockProposed(bytes32 proposal);

    /** Emitted when core status is changed. */
    event CoreStatusUpdated(CoreStatus status);

    /**  Emitted when core is opened for a first time after creation. */
    event GenesisOriginObservationStored(uint256 genesisOriginObservationBlockNumber);


    /* Structs */

    /** The kernel of a meta-block header */
    struct Kernel {
        // Note the height of the metablock in the metachain is omitted in the struct

        /** Hash of the metablock's parent */
        bytes32 parent;
        /** Added validators */
        address[] updatedValidators;
        /** Removed validators */
        uint256[] updatedReputation;
        /** Gas target to close the metablock */
        uint256 gasTarget;
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
        /** Source block number */
        uint256 sourceBlockNumber;
        /** Target block number */
        uint256 targetBlockNumber;
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
        "EIP712Domain(string name,string version,bytes32 metachainId,address verifyingContract)"
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
        "VoteMessage(bytes32 transitionHash,bytes32 source,bytes32 target,uint256 sourceBlockNumber,uint256 targetBlockNumber)"
    );

    /** Sentinel pointer for marking end of linked-list of proposals */
    bytes32 public constant SENTINEL_PROPOSALS = bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

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

    /** Metachain Id of the meta-blockchain */
    bytes32 public metachainId;

    /** Core status */
    CoreStatus public coreStatus;

    /** Epoch length */
    uint256 public epochLength;

    /** mapping of metablock height to Kernels */
    mapping(uint256 => Kernel) public kernels;

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

    /** Creation kernel height */
    uint256 public creationKernelHeight;

    /** Open kernel height */
    uint256 public openKernelHeight;

    /** Open kernel hash */
    bytes32 public openKernelHash;

    /** Committed accumulated gas */
    uint256 public committedAccumulatedGas;

    /** Committed dynasty number */
    uint256 public committedDynasty;

    /** Committed sourceBlockNumber */
    uint256 public committedSourceBlockNumber;

    // /** Closed transition object */
    // Transition public closedTransition;

    // /** Sealing vote message */
    // VoteMessage public sealedVoteMessage;

    /** Map kernel height to linked list of proposals */
    mapping(uint256 => mapping(bytes32 => bytes32)) proposals;

    /** Map proposal hash to VoteCount struct */
    mapping(bytes32 => VoteCount) public voteCounts;

    /** Map validator to proposal hash */
    mapping(address => bytes32) public votes;

    /** Precommitment to a proposal */
    bytes32 public precommit;

    /** Precommitment closure block number */
    uint256 public precommitClosureBlockNumber;

    /**
     * Block number at which core status is changed from creation to opened.
     * The initial validators are now known and they can create the genesis file.
     */
    uint256 public genesisOriginObservationBlockNumber;


    /* Modifiers */

    modifier beforeOpen()
    {
        require(
            coreStatus == CoreStatus.created,
            "The core must be created."
        );
        _;
    }

    modifier whileRunning()
    {
        require(
            coreStatus == CoreStatus.opened ||
            coreStatus == CoreStatus.precommitted,
            "The core must be running."
        );
        _;
    }

    modifier whileMetablockOpen()
    {
        require(
            coreStatus == CoreStatus.opened,
            "The core must have an open metablock kernel."
        );
        _;
    }

    modifier whileMetablockPrecommitted()
    {
        require(
            coreStatus == CoreStatus.precommitted,
            "The core must be precommitted."
        );
        _;
    }

    modifier duringPrecommitmentWindow()
    {
        require(
            block.number <= precommitClosureBlockNumber,
            "The precommitment window must be open."
        );
        _;
    }


    /* Special Functions */

    function setup(
        ConsensusI _consensus,
        bytes32 _metachainId,
        uint256 _epochLength,
        uint256 _minValidators,
        uint256 _joinLimit,
        ReputationI _reputation,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        uint256 _sourceBlockNumber
    )
        external
    {
        require(
            metachainId == bytes32(0),
            "Core is already setup."
        );

        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _epochLength != uint256(0),
            "Epoch length is 0."
        );

        require(
            _minValidators != uint256(0),
            "Min validators count is 0."
        );

        require(
            _joinLimit != uint256(0),
            "Validator's join limit is 0."
        );

        require(
            _reputation != ReputationI(0),
            "Reputation contract's address is null."
        );

        // TODO: remove before committing
        // require(
        //     (_height == uint256(0) && _parent == bytes32(0))
        //     || (_height != uint256(0) && _parent != bytes32(0)),
        //     "Height and parent can be 0 only together."
        // );

        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                DOMAIN_SEPARATOR_NAME,
                DOMAIN_SEPARATOR_VERSION,
                _metachainId,
                address(this)
            )
        );

        setupConsensus(_consensus);

        setupValidatorSet(_height);

        coreStatus = CoreStatus.created;

        epochLength = _epochLength;

        reputation = _reputation;

        minimumValidatorCount = _minValidators;
        joinLimit = _joinLimit;

        creationKernelHeight = _height;
        openKernelHeight = _height;

        Kernel storage creationKernel = kernels[_height];
        creationKernel.parent = _parent;
        creationKernel.gasTarget = _gasTarget;
        // before the Kernel can be opened, initial validators need to join

        committedDynasty = _dynasty;
        committedAccumulatedGas = _accumulatedGas;
        committedSourceBlockNumber = _sourceBlockNumber;

        emit CoreStatusUpdated(coreStatus);
    }


    /* External and public functions */

    /**
     * @notice Propose transition object and vote message from seal
     *         for the open kernel.
     *
     * @dev Function requires:
     *          - core is opened
     *          - the given kernel hash matches to the opened kernel hash in core
     *          - origin observation is not 0
     *          - dynasty is strictly greater than committed dynasty
     *          - accumulated gas is strictly greater than committed
     *            accumulated gas
     *          - committee lock (transition root hash) is not 0
     *          - source blockhash is not 0
     *          - target blockhash is not 0
     *          - source block height is strictly greater than committed
     *            block height
     *          - source block height is a checkpoint
     *          - target block height is +1 epoch of the source block height
     *          - a proposal matching with the input parameters does
     *            not exist in the core
     *
     * @param _kernelHash Kernel hash of a proposed metablock.
     * @param _originObservation Origin observation of a proposed metablock.
     * @param _dynasty Dynasty of a proposed metablock.
     * @param _accumulatedGas Accumulated gas in a proposed metablock.
     * @param _committeeLock Committee lock (transition root hash) of a proposed
     *                       metablock.
     * @param _source Source blockhash of a vote message for a proposed metablock.
     * @param _target Target blockhash of a vote message for a proposed metablock.
     * @param _sourceBlockNumber Source block number of a vote message for a
     *                           proposed metablock.
     * @param _targetBlockNumber Target block number of a vote message for a
     *                           proposed metablock.
     *
     * @return proposal_ Returns a proposal based on input parameters.
     */
    function proposeMetablock(
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        external
        whileMetablockOpen
        returns (bytes32 proposal_)
    {
        require(
            _kernelHash == openKernelHash,
            "A metablock can only be proposed for the open Kernel in this core."
        );
        require(
            _originObservation != bytes32(0),
            "Origin observation cannot be null."
        );
        require(
            _dynasty > committedDynasty,
            "Dynasty must strictly increase."
        );
        require(
            _accumulatedGas > committedAccumulatedGas,
            "Accumulated gas must strictly increase."
        );
        require(
            _committeeLock != bytes32(0),
            "Committee lock cannot be null."
        );
        require(
            _source != bytes32(0),
            "Source blockhash must not be null."
        );
        require(
            _target != bytes32(0),
            "Target blockhash must not be null."
        );
        require(
            _sourceBlockNumber > committedSourceBlockNumber,
            "Source block number must strictly increase."
        );
        require(
            (_sourceBlockNumber % epochLength) == 0,
            "Source block height must be a checkpoint."
        );
        require(
            _targetBlockNumber == _sourceBlockNumber.add(epochLength),
            "Target block number must equal source block number plus one."
        );

        bytes32 transitionHash = hashTransition(
            _kernelHash,
            _originObservation,
            _dynasty,
            _accumulatedGas,
            _committeeLock
        );

        proposal_ = hashVoteMessage(
            transitionHash,
            _source,
            _target,
            _sourceBlockNumber,
            _targetBlockNumber
        );

        // insert proposal, reverts if proposal already inserted
        insertProposal(_dynasty, proposal_);

        emit MetablockProposed(proposal_);
    }

    /**
     * @notice Registers a validator's vote for the given proposal.
     *         If the validator has already registered a vote for currently
     *         opened kernel height, it gets updated (only if dynasty number
     *         of the new vote is higher then the previous one).
     *
     * @dev Function requires:
     *          - core is in precommitment window
     *          - proposal is not 0
     *          - if core has precommitted, the given proposal matches with it
     *          - proposal exists at open kernel height
     *          - validator active in this core
     *          - validator should not be slashed in reputation contract
     *          - validator has not already cast the same vote
     *          - vote gets updated only if the new vote is at higher dynasty
     */
    function registerVote(
        bytes32 _proposal,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        external
        duringPrecommitmentWindow
    {
        require(
            _proposal != bytes32(0),
            "Proposal can not be null."
        );
        if (precommit != bytes32(0)) {
            require(
                _proposal == precommit,
                "Core has precommitted, only votes for precommitment are relevant."
            );
        }

        require(
            proposals[openKernelHeight][_proposal] != bytes32(0),
            "Proposal must be registered at open metablock height."
        );

        address validator = ecrecover(_proposal, _v, _r, _s);
        // check validator is registered to this core
        require(
            isValidator(validator),
            "Validator must be active in this core."
        );
        require(
            !reputation.isSlashed(validator),
            "Validator is slashed."
        );

        bytes32 castVote = votes[validator];
        require(
            castVote != _proposal,
            "Vote has already been cast."
        );

        VoteCount storage castVoteCount = voteCounts[castVote];
        VoteCount storage registerVoteCount = voteCounts[_proposal];
        if (castVoteCount.count != 0 && castVoteCount.height == openKernelHeight) {
            require(
                castVoteCount.dynasty < registerVoteCount.dynasty,
                "Vote can only be recast for higher dynasty numbers."
            );
            castVoteCount.count = castVoteCount.count.sub(1);
        }
        votes[validator] = _proposal;
        registerVoteCount.count = registerVoteCount.count.add(1);
        if (registerVoteCount.count >= quorum) {
            registerPrecommit(_proposal);
        }
    }

    /**
     * @notice Hashes given parameters of a metablock.
     *
     * @param _kernelHash Kernel hash of a provided metablock.
     * @param _originObservation Origin observation of a provided metablock.
     * @param _dynasty Dynasty of a provided metablock.
     * @param _accumulatedGas Accumulated gas in a provided metablock.
     * @param _committeeLock Committee lock (transition root hash) of a provided
     *                       metablock.
     * @param _source Source blockhash of a vote message for a
     *                provided metablock.
     * @param _target Target blockhash of a vote message for a
     *                provided metablock.
     * @param _sourceBlockNumber Source block number of a vote message for a
     *                           provided metablock.
     * @param _targetBlockNumber Target block number of a vote message for a
     *                           provided metablock.
     *
     * @return The precommit's hash.
     */
    function hashMetablock(
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        public
        view
        returns (bytes32 metablockHash_)
    {
        bytes32 transitionHash = hashTransition(
            _kernelHash,
            _originObservation,
            _dynasty,
            _accumulatedGas,
            _committeeLock
        );

        metablockHash_ = hashVoteMessage(
            transitionHash,
            _source,
            _target,
            _sourceBlockNumber,
            _targetBlockNumber
        );
    }

    /**
     * @notice Opens a new metablock if a proposal is precommitted.
     *
     * @dev Function requires:
     *          - core has precommitted
     *          - only consensus can call
     *          - input parameters match to an open metablock
     *
     * @param _committedDynasty Dynasty of an open metablock.
     * @param _committedAccumulatedGas Accumulated gas in an open metablock.
     * @param _committedSourceBlockNumber Source block number of a vote message
     *                                    for an open metablock.
     * @param _deltaGasTarget Gas target delta for a new metablock.
     */
    function openMetablock(
        uint256 _committedDynasty,
        uint256 _committedAccumulatedGas,
        uint256 _committedSourceBlockNumber,
        uint256 _deltaGasTarget
    )
        external
        onlyConsensus
        whileMetablockPrecommitted
    {
        assert(precommit != bytes32(0));

        committedDynasty = _committedDynasty;
        committedAccumulatedGas = _committedAccumulatedGas;
        committedSourceBlockNumber = _committedSourceBlockNumber;

        uint256 nextKernelHeight = openKernelHeight.add(1);
        Kernel storage nextKernel = kernels[nextKernelHeight];
        nextKernel.parent = precommit;
        nextKernel.gasTarget = committedAccumulatedGas
            .add(_deltaGasTarget);
        // updated validators are already written to nextKernel

        openKernelHeight = nextKernelHeight;

        openKernelHash = hashKernel(
            nextKernelHeight,
            nextKernel.parent,
            nextKernel.updatedValidators,
            nextKernel.updatedReputation,
            nextKernel.gasTarget
        );

        countValidators = countValidators
            .add(countJoinMessages)
            .sub(countLogOutMessages);
        quorum = calculateQuorum(countValidators);
        countJoinMessages = 0;
        countLogOutMessages = 0;

        newProposalSet();
    }

    /**
     * @notice Remove vote can be called by consensus when a validator
     *         is slashed, to retro-actively remove the vote from the
     *         current open metablock.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - core is in running state
     *
     * @param _validator Address of a validator to remove a vote.
     */
    function removeVote(
        address _validator
    )
        external
        onlyConsensus
        whileRunning
    {
        bytes32 castVote = votes[_validator];
        VoteCount storage castVoteCount = voteCounts[castVote];
        if (castVoteCount.height == openKernelHeight) {
            delete votes[_validator];
            castVoteCount.count = castVoteCount.count.sub(1);
        }
    }

    /**
     * @notice Joins a validator before core is opened.
     *         Once the minimum number of validators has joined, core is opened,
     *         with the metablock parameters specified in the constructor.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - core is created state and not open
     *          - a validator's address is not null
     *          - a validator has not already joined
     *
     * @param _validator A validator's address to join.
     *
     * @return validatorCount_ The total count of validators.
     * @return minValidatorCount_ Minimum validator count required set by consensus.
     * @return beginHeight_ Begin height of validator.
     */
    function joinBeforeOpen(
        address _validator
    )
        external
        onlyConsensus
        beforeOpen
        returns (
            uint256 validatorCount_,
            uint256 minValidatorCount_,
            uint256 beginHeight_
        )
    {
        // during created state, validators join at creation kernel height
        insertValidatorInternal(_validator, creationKernelHeight);

        Kernel storage creationKernel = kernels[creationKernelHeight];
        countValidators = creationKernel.updatedValidators.push(_validator);
        // TASK: reputation can be uint64, and initial rep set properly
        creationKernel.updatedReputation.push(uint256(1));
        if (countValidators >= minimumValidatorCount) {
            assert(countValidators == minimumValidatorCount);
            quorum = calculateQuorum(countValidators);
            precommitClosureBlockNumber = CORE_OPEN_VOTES_WINDOW;
            openKernelHash = hashKernel(
                creationKernelHeight,
                creationKernel.parent,
                creationKernel.updatedValidators,
                creationKernel.updatedReputation,
                creationKernel.gasTarget
            );
            genesisOriginObservationBlockNumber = block.number;
            // with the initial validator set determined, move the active height for joining up.
            ValidatorSet.incrementActiveHeightInternal(creationKernelHeight.add(1));
            emit GenesisOriginObservationStored(genesisOriginObservationBlockNumber);

            coreStatus = CoreStatus.opened;
            emit CoreStatusUpdated(coreStatus);

            newProposalSet();
        }

        // TODO (ben): clean up redundant variables
        validatorCount_ = countValidators;
        minValidatorCount_ = minimumValidatorCount;
        beginHeight_ = creationKernelHeight;
    }

    /**
     * @notice Joins a validator.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - core is in a running state
     *          - validators' join limit for the core has not been reached
     *          - maximum number of validators to join in a single metablock
     *            has not been reached
     *          - given validator address is not 0
     *          - validator has not joined
     *
     * @param _validator Address of a validator to join.
     *
     * @return beginHeight_ Begin height of the validator
     */
    function join(address _validator)
        external
        onlyConsensus
        whileRunning
        returns (uint256 beginHeight_)
    {
        require(
            countValidators
            .add(countJoinMessages)
            .sub(countLogOutMessages) < joinLimit,
            "Join limit is reached for this core."
        );
        require(
            countJoinMessages < MAX_DELTA_VALIDATORS,
            "Maximum number of validators that can join in one metablock is reached."
        );

        countJoinMessages = countJoinMessages.add(1);

        uint256 nextKernelHeight = openKernelHeight.add(1);

        // insertValidatorInternal asserts validator cannot join twice
        // insert validator starting from next metablock height
        insertValidatorInternal(_validator, nextKernelHeight);
        Kernel storage nextKernel = kernels[nextKernelHeight];
        nextKernel.updatedValidators.push(_validator);
        // TASK: reputation can be uint64, and initial rep set properly.
        nextKernel.updatedReputation.push(uint256(1));

        beginHeight_ = nextKernelHeight;
    }

    /**
     * @notice Logs out the validator.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - core is in a running state
     *          - validators' minimum limit has not been reached
     *          - maximum number of validators to logout in a single metablock
     *            has not been reached
     *          - given validator address is not 0
     *          - validator has joined
     *
     * @param _validator An address of the validator to logout.
     *
     * @return nextKernelHeight_ Next kernel height.
     */
    function logout(address _validator)
        external
        onlyConsensus
        whileRunning
        returns (uint256 nextKernelHeight_)
    {
        require(
            countValidators
            .add(countJoinMessages)
            .sub(countLogOutMessages) > minimumValidatorCount,
            "Validator minimum limit reached."
        );
        require(
            countLogOutMessages < MAX_DELTA_VALIDATORS,
            "Maximum number of validators that can log out in one metablock is reached."
        );

        nextKernelHeight_ = openKernelHeight.add(1);

        // removeValidatorInternal asserts validator is currently in the validator set and not already logged out.
        // remove validator from next metablock height
        removeValidatorInternal(_validator, nextKernelHeight_);

        Kernel storage nextKernel = kernels[nextKernelHeight_];
        nextKernel.updatedValidators.push(_validator);
        nextKernel.updatedReputation.push(uint256(0));

        countLogOutMessages = countLogOutMessages.add(1);
    }

    /**
     * It returns open kernel hash and height.
     *
     * @return Metablock's openKernelHash and openKernelHeight.
     */
    function getOpenKernel()
        external
        returns(bytes32 openKernelHash_, uint256 openKernelHeight_)
    {
        openKernelHash_ = openKernelHash;
        openKernelHeight_ = openKernelHeight;
    }


    /* Public functions */

    /**
     * @notice Validator is active if it is validator set at open kernel height.
     */
    function isValidator(address _account)
        public
        view
        returns (bool)
    {
        return inValidatorSet(_account, openKernelHeight);
    }

    function calculateQuorum(uint256 _count)
        public
        pure
        returns (uint256 quorum_)
    {
        quorum_ = _count
            .mul(CORE_SUPER_MAJORITY_NUMERATOR)
            .div(CORE_SUPER_MAJORITY_DENOMINATOR);
    }


    /* Internal and private functions */

    /**
     * @notice Precommits to a given proposal and lock core validators
     *         to associated responsibility.
     */
    function registerPrecommit(bytes32 _proposal)
        internal
    {
        require(
            precommit == bytes32(0) || precommit == _proposal,
            "Once locked, precommit cannot be changed."
        );

        if (coreStatus == CoreStatus.opened) {
            coreStatus = CoreStatus.precommitted;
            precommit = _proposal;
            precommitClosureBlockNumber = block.number.add(CORE_LAST_VOTES_WINDOW);
            consensus.precommitMetablock(metachainId, openKernelHeight, _proposal);

            emit CoreStatusUpdated(coreStatus);
        }
    }

    /**
     * @notice Starts new linked list for proposals at open kernel height.
     */
    function newProposalSet()
        internal
    {
        assert(proposals[openKernelHeight][SENTINEL_PROPOSALS] == bytes32(0));
        proposals[openKernelHeight][SENTINEL_PROPOSALS] = SENTINEL_PROPOSALS;
    }

    /**
     * @notice Inserts a proposal.
     *
     * @dev Function requires:
     *          - proposal hash is not 0
     *          - proposal does not exist
     *          - proposal is not a sentinel proposal
     *
     * @param _dynasty Dynasty of a metablock of a proposal.
     * @param _proposal Proposal hash.
     */
    function insertProposal(
        uint256 _dynasty,
        bytes32 _proposal
    )
        internal
    {
        // note: redundant because we always calculate the proposal hash
        require(
            _proposal != bytes32(0),
            "Proposal must not be null."
        );
        require(
            _proposal != SENTINEL_PROPOSALS,
            "Proposal must not be sentinel for proposals."
        );
        require(
            proposals[openKernelHeight][_proposal] == bytes32(0),
            "Proposal can only be inserted once."
        );

        VoteCount storage voteCount = voteCounts[_proposal];

        // vote registered for open kernel
        voteCount.height = openKernelHeight;
        // register dynasty of transition
        voteCount.dynasty = _dynasty;
        // vote count is zero
        voteCount.count = 0;

        proposals[openKernelHeight][_proposal] = proposals[openKernelHeight][SENTINEL_PROPOSALS];
        proposals[openKernelHeight][SENTINEL_PROPOSALS] = _proposal;
    }

    /**
     * @notice Clean proposals.
     *
     * note: improve logic, to be done partially in case too much gas needed
     *       double-check if logic is correct.
     */
    function cleanProposals(uint256 _height)
        internal
    {
        require(
            _height < openKernelHeight,
            "Only proposals of older kernels can be cleaned out."
        );
        bytes32 currentProposal = proposals[_height][SENTINEL_PROPOSALS];
        bytes32 deleteProposal = SENTINEL_PROPOSALS;
        require(
            currentProposal != bytes32(0),
            "There are no proposals to clear out."
        );
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
     * @notice Takes the parameters of a kernel object and returns the
     *         typed hash of it.
     *
     * @param _height The height of meta-block.
     * @param _parent The hash of this block's parent.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock
     *
     * @return hash_ The hash of kernel.
     */
    function hashKernel(
        uint256 _height,
        bytes32 _parent,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation,
        uint256 _gasTarget
    )
        public
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
                _gasTarget
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
        internal
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

    /**
    * @notice Takes the VoteMessage parameters and returns
     *        the typed VoteMessage hash.
     */
    function hashVoteMessage(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        internal
        view
        returns (bytes32 hash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                VOTE_MESSAGE_TYPEHASH,
                _transitionHash,
                _source,
                _target,
                _sourceBlockNumber,
                _targetBlockNumber
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

}
