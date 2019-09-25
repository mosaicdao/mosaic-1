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

import "../version/MosaicVersion.sol";

contract ProtoCore is MosaicVersion
{
    /* Usings */

    using SafeMath for uint256;


    /* Events */

    /** Logs that an origin block has been reported. */
    event OriginBlockReported(bytes32 blockHash);

    /** Logs that an origin block has been justified. */
    event OriginBlockJustified(bytes32 blockHash);

    /** Logs that an origin block has been finalised. */
    event OriginBlockFinalised(bytes32 blockHash);

    /** Logs that an auxiliary block has been reported. */
    event AuxiliaryBlockReported(bytes32 blockHash);

    /** Logs that an auxiliary block has been justified. */
    event AuxiliaryBlockJustified(bytes32 blockHash);

    /** Logs that an auxiliary block has been finalised. */
    event AuxiliaryBlockFinalised(bytes32 blockHash);


    /* Constants */

    /** Maximum future end dynasty. */
    uint256 public constant MAX_FUTURE_END_DYNASTY = uint256(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );

    /** EIP-712 domain separator name for ProtoCore. */
    string public constant DOMAIN_SEPARATOR_NAME = "Mosaic-ProtoCore";

    /** EIP-712 domain separator typehash for ProtoCore. */
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,bytes20 originCoreIdentifier,bytes20 auxiliaryCoreIdentifier,address verifyingContract)"
    );

    /** EIP-712 typehash for Kernel. */
    bytes32 public constant KERNEL_TYPEHASH = keccak256(
        "Kernel(uint256 height,bytes32 parent,address[] updatedValidators,uint256[] updatedReputation,uint256 gasTarget)"
    );

    /** EIP-712 typehash for an origin vote message. */
    bytes32 public constant ORIGIN_VOTE_MESSAGE_TYPEHASH = keccak256(
        "OriginVoteMessage(bytes20 coreIdentifier,bytes32 source,bytes32 target,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );

    /** EIP-712 typehash for an auxiliary vote message. */
    bytes32 public constant AUXILIARY_VOTE_MESSAGE_TYPEHASH = keccak256(
        "AuxiliaryVoteMessage(bytes20 coreIdentifier,bytes32 transitionHash,bytes32 source,bytes32 target,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );

    /** EIP-712 typehash for an auxiliary transition. */
    bytes32 public constant AUXILIARY_TRANSITION_TYPEHASH = keccak256(
        "AuxiliaryTransition(bytes20 coreIdentifier,bytes32 kernelHash,bytes32 originObservation,uint256 dynasty,uint256 accumulatedGas, bytes32 accumulatedTransactionRoot)"
    );


    /* Structs */

    /** A validator. */
    struct Validator
    {
        // Address of a validator.
        address addr;

        // Reputation of validator.
        uint256 reputation;

        // Start dynasty of validator.
        uint256 startDynasty;

        // End dynasty of validator.
        uint256 endDynasty;

        // Specifies if validator has been slashed or not.
        bool isSlashed;
    }

    /** A casper FFG checkpoint. */
    struct Checkpoint
    {
        /** The block hash of the block at this checkpoint. */
        bytes32 blockHash;

        /** The height of the checkpoint (not block). */
        uint256 height;

        /** The hash of the block of the parent checkpoint (not block) */
        bytes32 parent;

        /** Is true if the checkpoint has been justified. */
        bool justified;

        /** Is true if the checkpoint has been finalised. */
        bool finalised;

        // /**
        //  * The dynasty of block b is the number of finalized checkpoints in the
        //  * chain from the starting checkpoint to the parent of block b.
        //  */
        // uint256 dynasty;
    }

    /**
     * Tracking of an auxiliary transition object beginst at the "genesis"
     * checkpoint.
     */
    struct AuxiliaryTransitionObject
    {
        // Kernel hash while calculating auxiliary transition object.
        bytes32 kernelHash;

        // Latest observation of the origin chain while calculating
        // auxiliary transition object.
        bytes32 originLatestObservation;

        // The dynasty number equals the number of finalized checkpoints in the
        // chain from the root checkpoint to the parent block, carrying over
        // the definition of dynasty number as in Casper FFG.
        // For the genesis checkpoint, the dynasty number is 0.
        uint256 dynasty;

        // For the genesis checkpoint, the accumulated gas consumed equals
        // the gas consumed in the block. For all subsequent blocks, the
        // accumulated gas consumed G[i] at block height i is G[i−1] + G[i],
        // where G[i] is the gas consumed in the block at height i.
        uint256 accumulatedGas;

        // For the genesias checkpoint, the accumulated transaction root is
        // defined as the transaction root of the block. For all subsequent
        // blocks, the accumulated transaction root R[i] at block height i
        // is keccak256(R[i−1] , R[i]), where R[i] is the transaction root of
        // the block at height i
        bytes32 accumulatedTransactionRoot;
    }

    /** Vote message */
    struct VoteMessage {

        /**
         * A unique identifier that identifies what chain this vote is about.
         * To generate the vote hash coreIdentifier is needed. As the votes are
         * for both origin and auxiliary chain, the core identifier information
         * is stored in this struct.
         */
        bytes20 coreIdentifier;

        /**
         * The hash of the transition object of the meta-block that would
         * result from the source block being finalised and proposed to origin.
         */
        bytes32 transitionHash;

        /** The hash of the source block. */
        bytes32 source;

        /** The hash of the target block. */
        bytes32 target;

        /** The height of the source block. */
        uint256 sourceHeight;

        /** The height of the target block. */
        uint256 targetHeight;
    }

    /** Vote object */
    struct Vote {

        /** Vote message. */
        VoteMessage voteMessage;

        /** v component of signature */
        uint8 v;

        /** r component of signature */
        bytes32 r;

        /** s component of signature */
        bytes32 s;
    }

    struct VoteCount
    {
        uint256 forward;
        uint256 rear;
    }


    /* Storage */

    /** Domain separator */
    bytes32 internal domainSeparator;

    /** Origin chain's core identifier. */
    bytes20 internal originCoreIdentifier;

    /** Auxiliary chain's core identifier. */
    bytes20 internal auxiliaryCoreIdentifier;

    /** Epoch length is the number of blocks from one checkpoint to the next. */
    mapping(bytes20 => uint256) internal epochLengths;

    /** A mapping of block hashes to their reported headers. */
    mapping(bytes20 => mapping(bytes32 => Block.Header)) internal blocks;

    /**
     * A mapping of block hashes to parent checkpoints (represented
     * by blockhash).
     */
    mapping(bytes20 => mapping(bytes32 => bytes32)) internal parentCheckpoints;

    /** A mapping of block hashes to checkpoints. */
    mapping(bytes20 => mapping(bytes32 => Checkpoint)) internal checkpoints;

    mapping(bytes32 => VoteCount) internal votesCount;

    /** A mapping from a core identifier to the latest finalised blocks. */
    mapping(bytes20 => bytes32) internal latestFinalisedCheckpoints;

    /**
     * A mapping of auxiliary block hashes to their respective transition
     * objects.
     */
    mapping(bytes32 => AuxiliaryTransitionObject) internal auxiliaryTransitionObjects;

    /** Dynasty number of auxiliary blockchain. */
    uint256 internal auxiliaryDynasty;

    /**
     * Define a super-majority fraction used for justifying and finalising
     * checkpoints.
     */
    uint256 public constant SUPER_MAJORITY_NUMERATOR = uint256(2);
    uint256 public constant SUPER_MAJORITY_DENOMINATOR = uint256(3);

    /** A mapping from a validator address to a validator object. */
    mapping(address => Validator) internal validators;

    /** A sum of weights of all active validators. */
    uint256 internal activeValidatorsSummedWeight;

    /** A mapping from a hash(validatorAddress, voteHash) to boolean. */
    mapping(bytes32 => bool) internal validatorVoteHashes;

    /** A mapping from a vote hash to a sum of validator weights voted for it. */
    mapping(bytes32 => uint256) internal voteWeights;


    /* Special Member Functions */

    constructor()
        public
    {
        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                DOMAIN_SEPARATOR_NAME,
                DOMAIN_SEPARATOR_VERSION,
                originCoreIdentifier,
                auxiliaryCoreIdentifier,
                address(this)
            )
        );
    }


    /* External Functions */

    /**
     * @notice Reports a block of the origin chain.
     *
     * @param _blockHeaderRlp RLP encoded block header.
     */
    function reportOriginBlock(
        bytes calldata _blockHeaderRlp
    )
        external
    {
        Block.Header memory header = Block.decodeHeader(_blockHeaderRlp);

        _reportBlock(originCoreIdentifier, header);

        emit OriginBlockReported(header.blockHash);
    }

    /**
     * @notice Reports a block of the auxiliary chain.
     *
     * @param _blockHeaderRlp RLP encoded block header.
     */
    function reportAuxiliaryBlock(
        bytes calldata _blockHeaderRlp
    )
        external
    {
        Block.Header memory header = Block.decodeHeader(_blockHeaderRlp);

        _reportBlock(auxiliaryCoreIdentifier, header);

        _calculateAuxiliaryTransitionObject(header);

        emit AuxiliaryBlockReported(header.blockHash);
    }

    /**
     * @notice Cast a vote from a source to a target for origin chain.
     *         It is required that a source is an ancestor of a target in the
     *         checkpoint tree, otherwise the vote is considered invalid.
     *         If a public key of a validator is not in the validator set
     *         or a validator was slashed the vote is considered invalid.
     *
     * @dev Function requires:
     *          - source is justified
     *          - target is reported
     *          - height of target is bigger than height of source
     *          - a non-slashed validator has signed vote
     *          - validator has not already voted for the specified link
     *
     * @param _coreIdentifier A unique identifier that identifies what chain
     *                        this vote is about.
     * @param _sourceBlockHash The hash of any justified checkpoint.
     * @param _targetBlockHash The hash of any checkpoint that is descendent of source.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function voteOrigin(
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
    {
        (address validator, bytes32 voteHash) = _assertVoteValidity(
            originCoreIdentifier,
            bytes32(0), // transition hash is 0 for origin chain.
            _sourceBlockHash,
            _targetBlockHash
        );

        _storeVote(validator, voteHash);

        uint256 requiredWeight = _calculateOriginRequiredWeight();

        if (voteWeights[voteHash] >= requiredWeight) {
            Checkpoint storage targetCheckpoint = checkpoints[
                originCoreIdentifier
            ][_targetBlockHash];

            if (targetCheckpoint.justified) {
                return;
            }

            _justify(originCoreIdentifier, _targetBlockHash);

            if (distanceInEpochs(_sourceBlockHash, _targetBlockHash) == 1) {
                _finalise(originCoreIdentifier, _sourceBlockHash);
            }
        }
    }

    /**
     * @notice Cast a vote from a source to a target.
     *         It is required that a source is an ancestor of a target in the
     *         checkpoint tree, otherwise the vote is considered invalid.
     *         If a public key of a validator is not in the validator set
     *         or a validator was slashed the vote is considered invalid.
     *
     * @param _coreIdentifier A unique identifier that identifies what chain
     *                        this vote is about.
     * @param _transitionHash The hash of the transition object of the
     *                        meta-block that would result from the source
     *                        block being finalised and proposed to origin.
     * @param _source The hash of any justified checkpoint.
     * @param _target The hash of any checkpoint that is descendent of source.
     * @param _sourceHeight The height of a source checkpoint in the
     *                      checkpoint tree.
     * @param _targetHeight The height of a target checkpoint in the
     *                      checkpoint tree.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function castAuxiliaryVote(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceHeight,
        uint256 _targetHeight,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
    {
        require(
            _isBlockReported(originCoreIdentifier, _source),
            "Source is not reported."
        );

        require(
            _isAtCheckpoint(originCoreIdentifier, _source),
            "Source is not at checkpoint height."
        );

        require(
            _isJustified(originCoreIdentifier, _source),
            "Source is not justified."
        );

        require(
            _isBlockReported(originCoreIdentifier, _target),
            "Target is not reported."
        );

        require(
            _isAtCheckpoint(originCoreIdentifier, _source),
            "Target is not at checkpoint height."
        );

        sourceHeight = blocks[originCoreIdentifier][_source].blockHeight;
        targetHeight = blocks[originCoreIdentifier][_target].blockHeight;

        require(
            _sourceHeight < _targetHeight,
            "The source height must be less than the target height."
        );

        bytes32 voteHash = _hashVoteMessage(
            originCoreIdentifier,
            bytes32(0),
            _source,
            _target,
            sourceHeight,
            targetHeight
        );

        address validator = ecrecover(voteHash, _v, _r, _s);

        require(
            _validatorIsActive(validator),
            "The validator is not active."
        );

        require(
            _isAncestor(
                originCoreIdentifier,
                _source,
                _target
            ),
            "Source is not a descendent of a target."
        );

        require(
            _isAncestor(
                originCoreIdentifier,
                latestFinalizedCheckpoints[originCoreIdentifier],
                _source
            ),
            "Latest finalized checkpoint is not a descendent of a source."
        );

        Checkpoint storage targetCheckpoint = getCheckpoint(_target);
        uint256 targetDynasty = targetCheckpoint.dynasty;

        uint256 dynastyStatus = whichDynastyBelongs(
            targetDynasty, validator
        );

        if (dynastyStatus == 0) {
            // does not belong neither to start nor to end.
        } else if (dynastyStatus == 1) {
            // belongs only to start dynasty
        } else if (dynastyStatus == 2) {
            // belongs only to end dynasty
        } else if (dynastyStatus == 3) {
            // belongs both dynasties
        }
    }

    function slash(
        bytes32 _firstTransitionHash,
        bytes32 _firstSource,
        bytes32 _firstTarget,
        uint256 _firstSourceHeight,
        uint256 _firstTargetHeight,
        uint8 _firstV,
        bytes32 _firstR,
        bytes32 _firstS,
        bytes32 _secondTransitionHash,
        bytes32 _secondSource,
        bytes32 _secondTarget,
        uint256 _secondSourceHeight,
        uint256 _secondTargetHeight,
        uint8 _secondV,
        bytes32 _secondR,
        bytes32 _secondS
    )
        external;

    function openMetaBlock(
        address[] calldata _validators,
        uint256[] calldata _reputations
    )
        external;


    /* Public Functions */

    function isValidOriginVote(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceHeight,
        uint256 _targetHeight
    )
        public
        view
        returns (bool);

    function isValidAuxiliaryVote(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceHeight,
        uint256 _targetHeight
    )
        public
        view
        returns (bool);

    /**
     * @notice Checks if a block specified by a blockhash is reported for
     *         the origin chain.
     *
     * @param _blockHash Blockhash of a block to check.
     *
     * @return true if a block is reported, otherwise false.
     */
    function isOriginBlockReported(
        bytes32 _blockHash
    )
        public
        view
        returns (bool)
    {
        return _isBlockReported(originCoreIdentifier, _blockHash);
    }

    /**
     * @notice Checks if a block specified by a blockhash is reported for
     *         the auxiliary chain.
     *
     * @param _blockHash Blockhash of a block to check.
     *
     * @return true if a block is reported, otherwise false.
     */
    function isAuxiliaryBlockReported(
        bytes32 _blockHash
    )
        public
        view
        returns (bool)
    {
        return _isBlockReported(auxiliaryCoreIdentifier, _blockHash);
    }


    /* Internal Functions */

    /**
     * @notice Reports a block for a chain specified by a core identifier.
     *         If a block is at checkpoint height, creates a checkpoint.
     *
     * @dev Function assumes:
     *          - the block header validity
     *          - the core identifier validity
     *      Function requires:
     *          - the block has not been already reported
     *          - the reported block's parent block has been already reported
     *
     * @param _coreIdentifier A chain's core identifier.
     * @param _header RLP encoded block header.
     */
    function _reportBlock(
        bytes20 _coreIdentifier,
        Block.Header memory _header
    )
        internal
    {
        require(
            !_isBlockReported(_coreIdentifier, _header.blockHash),
            "The block was already reported."
        );

        require(
            _isBlockReported(_coreIdentifier, _header.parentHash),
            "The parent of the block to report must be reported first."
        );

        blocks[_coreIdentifier][_header.blockHash] = _header;

        bytes32 parentCheckpointHash = parentCheckpoints[_coreIdentifier][_header.parentHash];
        parentCheckpoints[_coreIdentifier][_header.blockHash] = parentCheckpointHash;

        if (_isAtCheckpoint(_coreIdentifier, _header.blockHash)) {
            Checkpoint storage checkpoint = checkpoints[_coreIdentifier][_blockHash];

            checkpoint.blockHash = _header.blockHash;

            Checkpoint storage parentCheckpoint = checkpoints[_coreIdentifier][parentCheckpointHash];
            checkpoint.height = parentCheckpoint.height;

            checkpoint.parent = parentCheckpoints[
                _coreIdentifier
            ][_header.blockHash];

            checkpoint.justified = false;
            checkpoint.finalised = false;

            parentCheckpoints[
                _coreIdentifier
            ][_header.blockHash] = _header.blockHash;
        }
    }

    /**
     * @notice Calculates and stores an auxiliary transition
     *         object.
     *
     * @dev Function assumes:
     *          - the block header validity
     *      Function requires:
     *          - a transition object for the block does not exist
     *          - a parent block for the block exists
     *          - a transition object for the parent block exists
     *
     * @param _header Block header to calculate a transition object.
     */
    function _calculateAuxiliaryTransitionObject(
        Block.Header memory _header
    )
        internal
    {
        require(
            auxiliaryTransitionObjects[_header.blockHash].kernelHash == bytes32(0),
            "Transition object of the block exists."
        );

        Block.Header storage parent = blocks[_header.parentHash];

        require(
            parent.blockHash != bytes32(0),
            "Parent block of the block does not exist."
        );

        require(
            auxiliaryTransitionObjects[
                parent.blockHash
            ].kernelHash != bytes32(0),
            "Transition object of the parent block does not exist."
        );

        // Assigning kernel hash.
        auxiliaryTransitionObjects[_header.blockHash].kernelHash = kernelHash;

        // Calculates accumulated gas for the specified block header.
        auxiliaryTransitionObjects[
            _header.blockHash
        ].accumulatedGas = auxiliaryTransitionObjects[
            parent.blockHash
        ].accumulatedGas.add(header.gasUsed);

        // Calculates accumulated transaction root for the specified
        // block header.
        auxiliaryTransitionObjects[
            _header.blockHash
        ].accumulatedTransactionRoot = keccak256(
            abi.encode(
                auxiliaryTransitionObjects[
                    parent.blockHash
                ].accumulatedTransactionRoot,
                _header.transactionRoot
            )
        );

        // Assigning latest observation of origin chain.
        auxiliaryTransitionObjects[
            _header.blockHash
        ].originLatestObservation = latestFinalizedCheckpoints[
            originCoreIdentifier
        ];

        // Assigning current dynasty number of auxiliary chain.
        auxiliaryTransitionObjects[
            _header.blockHash
        ].dynasty = auxiliaryDynasty;
    }

    /**
     * @notice Checks if a block specified by a blockhash is reported for
     *         a chain specified by a core identifier.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _blockHash Block hash of a block.
     *
     * @return true if the block is reported for the chain, otherwise false.
     */
    function _isBlockReported(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
        view
        returns (bool isBlockReported_)
    {
        isBlockReported_ = blocks[_coreIdentifier][_blockHash].blockHash == _blockHash;
    }

    /**
     * @notice Checks if a block specified by a blockhash is at checkpoint
     *         height for a chain specified by a core identifier.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *      Function requires:
     *          - the block is reported
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _blockHash Block hash of a block.
     *
     * @return true if the block (specified by the blockhash) is at checkpoint
     *         height for the chain (specified by the core identifier).
     */
    function _isAtCheckpoint(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
        view
        returns (bool atCheckpoint_)
    {
        require(
            _isBlockReported(_coreIdentifier, _blockHash),
            "Block is not reported."
        );

        uint256 blockHeight = blocks[_coreIdentifier][_blockHash].height;

        atCheckpoint_ = _isAtCheckpointHeight(
            _coreIdentifier,
            blockHeight
        );
    }

    /**
     * @notice Checks if the given height corresponds to a valid
     *         checkpoint height (multiple of the epoch length) for the
     *         chain.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _height The block height to check.
     *
     * @return true if the given height is at a checkpoint height,
     *         otherwise false.
     */
    function _isAtCheckpointHeight(
        bytes20 _coreIdentifier,
        uint256 _height
    )
        internal
        view
        returns (bool atCheckpointHeight_)
    {
        atCheckpointHeight_ = _height.mod(epochLengths[_coreIdentifier]) == 0;
    }

    /**
     * @notice Checks if a block specified by a blockhash is justified for
     *         a chain specified by a core identifier.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *      Function requires:
     *          - block is at checkpoint height
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _blockHash Block hash of a block.
     *
     * @return true if the given block is justified, otherwise false.
     */
    function _isJustified(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
        view
        returns (bool isJustified_)
    {
        require(
            _isAtCheckpoint(_coreIdentifier, _blockHash),
            "Block is not at checkpoint height."
        );

        Checkpoint storage checkpoint = checkpoints[
            _coreIdentifier
        ][_blockHash];

        isJustified_ = checkpoint.justified;
    }

    /**
     * @notice Checks if a block specified by a blockhash is finalised for
     *         a chain specified by a core identifier.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *      Function requires:
     *          - block is at checkpoint height
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _blockHash Block hash of a block.
     *
     * @return true if the given block is finalised, otherwise false.
     */
    function _isFinalised(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
        view
        coreIsKnown(_coreIdentifier)
        returns (bool isFinalised_)
    {
        require(
            _isAtCheckpoint(_coreIdentifier, _blockHash),
            "Block is not at checkpoint height."
        );

        Checkpoint storage checkpoint = justifiedCheckpoints[
            _coreIdentifier
        ][_blockHash];

        isJustified_ = checkpoint.finalised;
    }

    /**
     * @notice Checks if a source block specified by a blockhash is an
     *         ancestor for a target block specified by a blockhash in a
     *         checkpoint tree of a chain specified by a core identifier.
     *         Function traverses the checkpoint tree backward (to the
     *         checkpoint tree root) from the target block till it "meets"
     *         the source block.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *          - the source block is justified
     *          - the target block is at checkpoint height
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _sourceBlockHash Block hash of a source block.
     * @param _targetBlockHash Block hash of a target block.
     *
     * @return true if source block is an ancestor of target block in chain.
     */
    function _isAncestorInCheckpointTree(
        _coreIdentifier,
        _sourceBlockHash,
        _targetBlockHash
    )
        internal
        view
        returns (bool isAncestor_)
    {
        Checkpoint storage source = checkpoints[_coreIdentifier][_sourceBlockHash];
        Checkpoint storage target = checkpoints[_coreIdentifier][_targetBlockHash];

        sourceHeight = source.height;
        targetHeight = target.height;

        if(_sourceHeight < _targetHeight) {
            isAncestor_ = false;
            return;
        }

        Checkpoint storage pointer = target;
        do {
            pointer = checkpoints[_coreIdentifier][pointer.parent];
        } while (
            pointer.height > source.height
        );

        isAncestor_ = pointer.blockHash == _sourceBlockHash;
    }

    /** Returns true if validator exists and is not slashed, otherwise false. */
    function _validatorIsActive(
        address _validatorAddress
    )
        internal
        view
        returns (bool isActive_)
    {
        Validator storage validator = validators[validatorAddress];

        isActive_ = validator.addr != address(0) && !validator.isSlashed;
    }

    /**
     * @notice Function asserts the specified vote validity.
     *         Vote is invalid if:
     *              - the source block is not justified
     *              - the target block is not at checkpoint height
     *              - the source block is not an ancestor of the target block
     *              - the vote is signed by an inactive validator (
     *                non-registered or slashed).
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *
     * @param _coreIdentifier A unique identifier that identifies what chain
     *                        this vote is about.
     * @param _transitionHash The hash of the transition object.
     * @param _sourceBlockHash The hash of any justified checkpoint.
     * @param _targetBlockHash The hash of any checkpoint that is descendent
     *                         of source.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function _assertVoteValidity(
        bytes20 _coreIdentifier,
        bytes32 _transitionHash,
        bytes32 _sourceBlockhash,
        bytes32 _targetBlockhash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        view
        returns (address validator_, bytes32 voteHash_)
    {
        require(
            _isJustified(_coreIdentifier, _sourceBlockHash),
            "Source is not justified."
        );

        require(
            _isAtCheckpoint(_coreIdentifier, _targetBlockhash),
            "Target is not reported."
        );

        sourceHeight = blocks[_coreIdentifier][_sourceBlockHash].blockHeight;
        targetHeight = blocks[_coreIdentifier][_targetBlockhash].blockHeight;

        voteHash_ = _hashVoteMessage(
            _coreIdentifier,
            _transitionHash,
            _sourceBlockHash,
            _targetBlockhash,
            sourceHeight,
            targetHeight
        );

        validator_ = ecrecover(voteHash, _v, _r, _s);

        require(
            _validatorIsActive(validator_),
            "The validator is not active."
        );

        require(
            _isAncestorInCheckpointTree(
                _coreIdentifier,
                _sourceBlockHash,
                _targetBlockhash
            ),
            "Source is not an ancestor of a target."
        );
    }

    /**
     * @notice Stores a validator vote.
     *
     * @dev Function requires:
     *          - the valiator has not casted the same vote already
     */
    function _storeVote(
        address validator,
        bytes32 voteHash
    )
        internal
    {
        bytes32 validatorVoteHash = keccak256(
            abi.encode(
                validator,
                voteHash
            )
        );

        require(
            !validatorVoteHashes[validatorVoteHash],
            "Validator has already voted for this link."
        );

        validatorVoteHashes[validatorVoteHash] = true;

        uint256 validatorWeight = _validatorWeight(validator);

        voteWeights[voteHash] = voteWeights[voteHash].add(validatorWeight);
    }

    function _calculateOriginRequiredWeight()
        internal
        view
        returns (uint256 requiredWeight_)
    {
        requiredWeight_ = _calculateSupermajorityAmount(
            activeValidatorsSummedWeight
        );
    }

    function _calculateSupermajorityAmount(uint256 _count)
        internal
        pure
        returns (uint256 supermajorityAmount_)
    {
        supermajorityAmount_ = _count * SUPER_MAJORITY_NUMERATOR /
            SUPER_MAJORITY_DENOMINATOR;
    }

    /**
     * @notice Justifies the given block.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *          - the block is a checkpoint
     */
    function _justify(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
    {
        Checkpoint storage checkpoint = checkpoints[_coreIdentifier][_blockHash];
        checkpoint.justified = true;
    }

    /**
     * @notice Finalises the given block.
     *
     * @dev Function assumes:
     *          - the core identifier validity
     *          - the block is a justified checkpoint
     */
    function _finalise(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
    {
        Checkpoint storage checkpoint = checkpoints[_coreIdentifier][_blockHash];
        checkpoint.finalised = true;
    }

    /**
     * @notice Calculates and returns the number of epochs between two given
     *         blocks.
     *
     * @dev Function requires:
     *          - the specified core is known by the contract
     *
     * @param _coreIdentifier Core identifier of a chain.
     * @param _lowerBlockHash Block hash of the lower block.
     * @param _higherBlockHash Block hash of the higher block.
     *
     * @return The distance between the given blocks in number of epochs.
     */
    function distanceInEpochs(
        bytes20 _coreIdentifier,
        bytes32 _lowerBlockHash,
        bytes32 _higherBlockHash
    )
        private
        view
        returns (uint256 epochDistance_)
    {
        uint256 lowerHeight = blocks[_coreIdentifier][_lowerBlockHash].height;
        uint256 higherHeight = blocks[_coreIdentifier][_higherBlockHash].height;
        uint256 blockDistance = higherHeight.sub(lowerHeight);
        epochDistance_ = blockDistance.div(epochLength);
    }

    function _hashVoteMessage(
        bytes20 _coreIdentifier,
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        coreIsKnown(_coreIdentifier)
        returns (bytes32 voteHash_)
    {
        if (_coreIdentifier == originCoreIdentifier) {
            require(
                _transitionHash == bytes32(0),
                "Transition hash for origin vote should be 0."
            );
            voteHash_ = _hashOriginVoteMessage(
                _source,
                _target,
                _sourceBlockHeight,
                _targetBlockHeight
            );
        } else if (_coreIdentifier == auxiliaryCoreIdentifier) {
            voteHash_ = _hashAuxiliaryVoteMessage(
                _transitionHash,
                _source,
                _target,
                _sourceBlockHeight,
                _targetBlockHeight
            );
        } else {
            voteHash_ = bytes32(0);
        }
    }

    function _hashOriginVoteMessage(
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        returns (bytes32 hash_)
    {
        require(_source != bytes32(0));
        require(_target != bytes32(0));

        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                ORIGIN_VOTE_MESSAGE_TYPEHASH,
                originCoreIdentifier,
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

    function _hashAuxiliaryVoteMessage(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        returns (bytes32 hash_)
    {
        require(_transitionHash != bytes32(0));
        require(_source != bytes32(0));
        require(_target != bytes32(0));

        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                AUXILIARY_VOTE_MESSAGE_TYPEHASH,
                auxiliaryCoreIdentifier,
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

    /**
     * @notice Creates a vote object.
     *
     * @param _coreIdentifier A unique identifier that identifies what chain
     *                        this vote is about.
     * @param _transitionHash The hash of the transition object of the
     *                        meta-block that would result from the source
     *                        block being finalised and proposed to origin.
     * @param _source The hash of the source block.
     * @param _target The hash of the target block.
     * @param _sourceHeight The height of the source block.
     * @param _targetHeight The height of the target block.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     *
     * @return voteObject_ vote object
     */
    function getVoteObject(
        bytes20 _coreIdentifier,
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceHeight,
        uint256 _targetHeight,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        private
        pure
        returns (Vote memory voteObject_)
    {
        VoteMessage memory voteMessage = VoteMessage(
            _coreIdentifier,
            _transitionHash,
            _source,
            _target,
            _sourceHeight,
            _targetHeight
        );

        voteObject_ = Vote(
            voteMessage,
            _v,
            _r,
            _s
        );
    }

    function _commit() internal;

    function _slash() internal;

    function _calculateValidatorWeight(
        ValidatorInfo memory _validatorInfo
    )
        internal
        view
        returns (_validatorWeight);

    function _updateValidators() internal;
}
