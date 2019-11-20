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

import "../block/Block.sol";
import "../version/MosaicVersion.sol";

contract ProtoCore is MosaicVersion
{
    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /** Maximum future end height of a validator. */
    uint256 public constant VALIDATOR_MAX_FUTURE_END_HEIGHT = uint256(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );

    /** EIP-712 domain separator name for ProtoCore. */
    string public constant DOMAIN_SEPARATOR_NAME = "Mosaic-ProtoCore";

    /** EIP-712 domain separator typehash for ProtoCore. */
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,bytes20 originCoreIdentifier,bytes20 auxiliaryCoreIdentifier,address verifyingContract)"
    );

    /** EIP-712 typehash for kernel. */
    bytes32 public constant KERNEL_TYPEHASH = keccak256(
        "Kernel(uint256 height,bytes32 parent,address[] updatedValidators,uint256[] updatedReputation,uint256 gasTarget)"
    );

    /** EIP-712 typehash for an origin vote message. */
    bytes32 public constant ORIGIN_VOTE_MESSAGE_TYPEHASH = keccak256(
        "OriginVoteMessage(bytes20 coreIdentifier,bytes32 sourceBlockHash,bytes32 targetBlockHash,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );

    /** EIP-712 typehash for an auxiliary vote message. */
    bytes32 public constant AUXILIARY_VOTE_MESSAGE_TYPEHASH = keccak256(
        "AuxiliaryVoteMessage(bytes20 coreIdentifier,bytes32 transitionHash,bytes32 sourceBlockHash,bytes32 targetBlockHash,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );

    /** EIP-712 typehash for an auxiliary transition. */
    bytes32 public constant AUXILIARY_TRANSITION_TYPEHASH = keccak256(
        "AuxiliaryTransition(bytes20 coreIdentifier,bytes32 kernelHash,bytes32 latestOriginObservation,uint256 auxiliaryDynasty,uint256 accumulatedGas, bytes32 accumulatedTransactionRoot)"
    );


    /* Structs */

    /** A validator. */
    struct Validator
    {
        // Address of a validator.
        address publicAddress;

        // Reputation of a validator.
        uint256 reputation;

        // Start height of a validator.
        uint256 startHeight;

        // End height of a validator.
        uint256 endHeight;

        // Specifies if a validator has been slashed or not.
        bool isSlashed;
    }

    /** A casper FFG checkpoint. */
    struct Checkpoint
    {
        /** Block hash of a block at this checkpoint. */
        bytes32 blockHash;

        /** Height of the checkpoint (not a block). */
        uint256 height;

        /** Hash of a block of the parent checkpoint (not a parent block hash) */
        bytes32 parentBlockHash;

        /** True if the checkpoint has been justified. */
        bool justified;

        /** True if the checkpoint has been finalised. */
        bool finalised;

        /**
         * Dynasty of a checkpoint 'c' is the number of finalised checkpoints
         * in a chain from the genesis checkpoint to the parent of
         * the checkpoin 'c'.
         *
         * Dynasty is currently used only for the auxiliary chain's blocks.
         */
        uint256 dynasty;
    }

    /**
     * An auxiliary transition object.
     * Tracking of an auxiliary transition object begins at the "genesis"
     * checkpoint.
     */
    struct AuxiliaryTransitionObject
    {
        // Kernel hash while calculating an auxiliary transition object.
        bytes32 kernelHash;

        // Latest observation of the origin chain while calculating
        // an auxiliary transition object.
        bytes32 originLatestObservation;

        // The dynasty numbner of the auxiliary chain while calculating
        // an auxiliary transition object. The dynasty equals to the number of
        // finalized checkpoints in the chain from the root checkpoint to
        // the parent checkpoint, carrying over the definition of dynasty
        // as in Casper FFG. For the genesis checkpoint, the dynasty is 0.
        uint256 dynasty;

        // The accumulated gas while calculating an auxiliary transition object.
        // For the genesis checkpoint, the accumulated gas consumed equals
        // the gas consumed in the block. For all subsequent blocks, the
        // accumulated gas consumed at block height i, AG[i] = AG[i−1] + G[i],
        // where G[i] is the gas consumed in the block at height i.
        uint256 accumulatedGas;

        // The accumulated transaction root while calculating an auxiliary
        // transition object. For the genesias checkpoint, the accumulated
        // transaction root is defined as the transaction root of the block.
        // For all subsequent blocks, the accumulated transaction root AR[i] at
        // block height i is AR[i] = keccak256(AR[i−1] , R[i]), where R[i] is
        // the transaction root of the block at height i.
        bytes32 accumulatedTransactionRoot;
    }


    /* Storage */

    /** EIP-712 domain separator. */
    bytes32 internal domainSeparator;

    /** Origin chain core identifier. */
    bytes20 internal originCoreIdentifier;

    /** Auxiliary chain core identifier. */
    bytes20 internal auxiliaryCoreIdentifier;

    /** Open kernel hash. */
    bytes32 internal kernelHash;

    /**
     * A mapping from a core identifier to corresponding epoch length.
     * Epoch length is the number of blocks from one checkpoint to the next.
     */
    mapping(bytes20 => uint256) internal epochLengths;

    /**
     * A mapping (per core identifier) of block hashes to their
     * reported headers.
     */
    mapping(bytes20 => mapping(bytes32 => Block.Header)) internal blocks;

    /**
     * Auxiliary self-referenced blocks are reported in 256 block-window
     * which allows to check block validity against EVM.
     */
    mapping(bytes32 => bool) internal selfReferencedAuxiliaryBlocks;

    /** Latest observation of the origin chain. */
    bytes32 internal originLatestObservation;

    /** A highest dynast number of the auxiliary chain. */
    uint256 internal auxiliaryHighestDynasty;

    /** The tip/head checkpoint's blockhash per core identifier. */
    mapping(bytes20 => bytes32) internal tipCheckpointBlockHashes;

    /** The tip/head checkpoint's height per core identifier. */
    mapping(bytes20 => uint256) internal tipCheckpointHeights;

    /** A mapping of block hash to a checkpoint (per core identifier). */
    mapping(bytes20 => mapping(bytes32 => Checkpoint)) internal checkpoints;

    /** A mapping of an auxiliary block hash to transition object. */
    mapping(bytes32 => AuxiliaryTransitionObject) internal auxiliaryTransitionObjects;

    /**
     * Defines a super-majority fraction used for justifying and finalising
     * checkpoints.
     */
    uint256 public constant SUPER_MAJORITY_NUMERATOR = uint256(2);
    uint256 public constant SUPER_MAJORITY_DENOMINATOR = uint256(3);

    /** A mapping from a validator address to a validator object. */
    mapping(address => Validator) internal validators;

    /** A mapping from a hash(validatorAddress, voteHash) to boolean. */
    mapping(bytes32 => bool) internal validatorVoteHashes;

    /**
     * A sum of weights of all active validators; it is used to check if a
     * quorum has been reached for a casper game of the origin chain.
     */
    uint256 internal activeValidatorsSummedWeight;

    /**
     * A mapping from an origin vote hash to the sum of weights of validators
     * voted for it.
     */
    mapping(bytes32 => uint256) internal originVoteWeights;

    /**
     * A mapping from a vote hash to the sum of validators' (from a forward set)
     * weights voted for it.
     */
    mapping(bytes32 => uint256) internal auxiliaryVoteWeightsByForwardSet;

    /**
     * A mapping from a vote hash to the sum of validators' (from a rear set)
     * weights voted for it.
     */
    mapping(bytes32 => uint256) internal auxiliaryVoteWeightsByRearSet;


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

        if (_isAtCheckpoint(auxiliaryCoreIdentifier, header.blockHash)) {
            Checkpoint storage checkpoint = checkpoints[
                auxiliaryCoreIdentifier
            ][header.blockHash];

            Checkpoint storage parentCheckpoint = checkpoints[
                auxiliaryCoreIdentifier
            ][header.parentHash];

            checkpoint.dynasty = parentCheckpoint.dynasty;
        }

        _selfReferenceAuxiliaryBlock(header);

        _calculateAuxiliaryTransitionObject(header);
    }

    /**
     * @notice Casts a vote from a source to a target on the origin chain.
     *
     * @dev Function requires:
     *          - source is a justified checkpoint
     *          - target is a checkpoint
     *          - source is an ancestor of a target
     *          - a non-slashed validator has signed vote
     *          - validator has not voted for this link
     *
     * @param _sourceBlockHash A source block hash.
     * @param _targetBlockHash A target block hash.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function castOriginVote(
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
    {
        (
            uint256 sourceBlockHeight,
            uint256 targetBlockHeight,
            address validator,
            bytes32 voteHash,
            bytes32 validatorVoteHash
        ) = _assertVoteValidity(
            originCoreIdentifier,
            bytes32(0), // transition hash is 0 for origin chain.
            _sourceBlockHash,
            _targetBlockHash,
            _v,
            _r,
            _s
        );

        _storeOriginVote(validator, voteHash, validatorVoteHash);

        uint256 requiredWeight = _calculateOriginRequiredWeight();

        if (originVoteWeights[voteHash] >= requiredWeight) {

            Checkpoint storage targetCheckpoint = checkpoints[
                originCoreIdentifier
            ][_targetBlockHash];

            if (targetCheckpoint.justified) {
                return;
            }

            _justify(originCoreIdentifier, _targetBlockHash);

            if (distanceInEpochs(originCoreIdentifier, _sourceBlockHash, _targetBlockHash) == 1) {
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
     * @param _transitionHash The hash of the transition object of the
     *                        meta-block that would result from the source
     *                        block being finalised and proposed to origin.
     * @param _sourceBlockHash The hash of any justified checkpoint.
     * @param _targetBlockHash The hash of any checkpoint that is descendent
     *                         of source.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function castAuxiliaryVote(
        bytes32 _transitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
    {
        (
            uint256 sourceBlockHeight,
            uint256 targetBlockHeight,
            address validator,
            bytes32 voteHash,
            bytes32 validatorVoteHash
        ) = _assertAuxiliaryVoteValidity(
            _transitionHash,
            _sourceBlockHash,
            _targetBlockHash,
            _v,
            _r,
            _s
        );

        if (sourceBlockHeight.add(1) == targetBlockHeight) {
            _assertInclusion(_targetBlockHash);
        }

        uint256 targetMetaBlockHeight = _metaBlockHeight(_targetBlockHash);

        if (_belongsToForwardSet(validator, targetMetaBlockHeight)) {
            _storeAuxiliaryForwardVote(validator, voteHash, validatorVoteHash);
        }

        if (_belongsToRearSet(validator, targetMetaBlockHeight)) {
            _storeAuxiliaryRearVote(validator, voteHash, validatorVoteHash);
        }

        if (_isAuxiliaryForwardQuorumReached(voteHash) && _isAuxiliaryRearQuorumReached(voteHash) ) {
            // justify
            // finalise
        }
    }

    function slashOrigin(
        bytes32 _firstSourceBlockHash,
        bytes32 _firstTargetBlockHash,
        uint8 _firstV,
        bytes32 _firstR,
        bytes32 _firstS,
        bytes32 _secondSourceBlockHash,
        bytes32 _secondTargetBlockHash,
        uint8 _secondV,
        bytes32 _secondR,
        bytes32 _secondS
    )
        external;

    function slashAuxiliary(
        bytes32 _firstTransitionHash,
        bytes32 _firstSourceBlockHash,
        bytes32 _firstTargetBlockHash,
        uint8 _firstV,
        bytes32 _firstR,
        bytes32 _firstS,
        bytes32 _secondTransitionHash,
        bytes32 _secondSourceBlockHash,
        bytes32 _secondTargetBlockHash,
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
     *         If the block is at checkpoint height, creates a checkpoint.
     *
     * @dev Function assumes:
     *          - the block header validity
     *          - the core identifier validity
     *      Function requires:
     *          - the block has not been already reported
     *          - the reported block's parent block has been already reported
     *          - the height of the block is +1 of the parent block height
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

        Block.Header storage parent = blocks[_coreIdentifier][_header.parentHash];
        require(
            parent.height.add(1) == _header.height,
            "The parent must have a height of one below the reported header."
        );

        blocks[_coreIdentifier][_header.blockHash] = _header;

        if (_isAtCheckpoint(_coreIdentifier, _header.blockHash)) {
            _addCheckpoint(_coreIdentifier, _header.blockHash);
        }
    }

    /**
     * @notice Adds checkpoint.
     *
     * @dev Function assumes:
     *          - the block is at checkpoint height
     *          - the checkpoint was not added
     *
     * @param _coreIdentifier A chain's core identifier.
     * @param _blockHash A block's hash to add as a checkpoint.
     */
    function _addCheckpoint(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
    {
        Checkpoint storage checkpoint = checkpoints[_coreIdentifier][_blockHash];

        checkpoint.blockHash = _blockHash;

        checkpoint.parentBlockHash = tipCheckpointBlockHashes[_coreIdentifier];
        checkpoint.height = tipCheckpointHeights[_coreIdentifier].add(1);

        checkpoint.justified = false;
        checkpoint.finalised = false;

        // Updating the tip checkpoint's block hash and height.
        tipCheckpointBlockHashes[_coreIdentifier] = _blockHash;
        tipCheckpointHeights[_coreIdentifier] = tipCheckpointHeights[
            _coreIdentifier
        ].add(1);
    }

    /**
     * @notice Self references the block if the block number is within
     *         256 blocks window.
     */
    function _selfReferenceAuxiliaryBlock(
        Block.Header memory _header
    )
        internal
    {
        if (_header.height.add(256) >= block.number) {
            require(
                blockhash(_header.height) == _header.blockHash,
                "Reported block is invalid."
            );

            selfReferencedAuxiliaryBlocks[_header.blockHash] = true;
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

        Block.Header storage parent = blocks[auxiliaryCoreIdentifier][_header.parentHash];

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
        ].accumulatedGas.add(_header.gasUsed);

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
        ].originLatestObservation = originLatestObservation;

        // Assigning highest dynasty number of auxiliary chain.
        auxiliaryTransitionObjects[
            _header.blockHash
        ].dynasty = auxiliaryHighestDynasty;
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

    function _isSelfReferenced(
        bytes32 _blockHash
    )
        internal
        view
        returns (bool isSelfReferenced_)
    {
        isSelfReferenced_ = selfReferencedAuxiliaryBlocks[_blockHash];
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
        returns (bool isFinalised_)
    {
        require(
            _isAtCheckpoint(_coreIdentifier, _blockHash),
            "Block is not at checkpoint height."
        );

        Checkpoint storage checkpoint = checkpoints[
            _coreIdentifier
        ][_blockHash];

        isFinalised_ = checkpoint.finalised;
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
        bytes20 _coreIdentifier,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash
    )
        internal
        view
        returns (bool isAncestor_)
    {
        Checkpoint storage sourceCheckpoint = checkpoints[
            _coreIdentifier
        ][_sourceBlockHash];

        Checkpoint storage targetCheckpoint = checkpoints[
            _coreIdentifier
        ][_targetBlockHash];

        uint256 sourceCheckpointHeight = sourceCheckpoint.height;
        uint256 targetCheckpointHeight = targetCheckpoint.height;

        if(sourceCheckpointHeight < targetCheckpointHeight) {
            isAncestor_ = false;
            return isAncestor_;
        }

        Checkpoint storage pointer = targetCheckpoint;
        do {
            pointer = checkpoints[_coreIdentifier][pointer.parentBlockHash];
        } while (
            pointer.height > sourceCheckpoint.height
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
        Validator storage validator = validators[_validatorAddress];

        isActive_ = validator.publicAddress != address(0) && !validator.isSlashed;
    }

    /**
     * @notice Function asserts the specified vote validity.
     *         Vote is invalid if:
     *              - source block is not a justified checkpoint
     *              - target block is not a checkpoint
     *              - source block is not an ancestor of target block
     *              - vote is signed by an inactive validator (non-registered
     *                or slashed).
     *              - validator has not voted for the same link already
     *
     * @dev Function assumes:
     *          - core identifier validity
     *
     * @param _coreIdentifier A unique identifier that identifies what chain
     *                        this vote is about.
     * @param _transitionHash Hash of transition object.
     * @param _sourceBlockHash Hash of source block.
     * @param _targetBlockHash Hash of target block.
     *                         of source.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function _assertVoteValidity(
        bytes20 _coreIdentifier,
        bytes32 _transitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        view
        returns (
            uint256 sourceBlockHeight_,
            uint256 targetBlockHeight_,
            address validator_,
            bytes32 voteHash_,
            bytes32 validatorVoteHash_
        )
    {
        require(
            _isJustified(_coreIdentifier, _sourceBlockHash),
            "Source is not a justified checkpoint."
        );

        require(
            _isAtCheckpoint(_coreIdentifier, _targetBlockHash),
            "Target is not a checkpoint."
        );

        sourceBlockHeight_ = blocks[
            _coreIdentifier
        ][_sourceBlockHash].height;

        targetBlockHeight_ = blocks[
            _coreIdentifier
        ][_targetBlockHash].height;

        voteHash_ = _hashVoteMessage(
            _coreIdentifier,
            _transitionHash,
            _sourceBlockHash,
            _targetBlockHash,
            sourceBlockHeight_,
            targetBlockHeight_
        );

        validator_ = ecrecover(voteHash_, _v, _r, _s);

        require(
            _validatorIsActive(validator_),
            "The validator is not active."
        );

        validatorVoteHash_ = keccak256(
            abi.encode(
                validator_,
                voteHash_
            )
        );

        require(
            !validatorVoteHashes[validatorVoteHash_],
            "Validator has already voted for this link."
        );

        require(
            _isAncestorInCheckpointTree(
                _coreIdentifier,
                _sourceBlockHash,
                _targetBlockHash
            ),
            "Source is not an ancestor of target."
        );
    }

    function _assertAuxiliaryVoteValidity(
        bytes32 _transitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        view
        returns (
            uint256 sourceBlockHeight_,
            uint256 targetBlockHeight_,
            address validator_,
            bytes32 voteHash_,
            bytes32 validatorVoteHash_
        )
    {
        (
            sourceBlockHeight_,
            targetBlockHeight_,
            validator_,
            voteHash_,
            validatorVoteHash_
        ) = _assertVoteValidity(
            auxiliaryCoreIdentifier,
            _transitionHash,
            _sourceBlockHash,
            _targetBlockHash,
            _v,
            _r,
            _s
        );

        require(
            _isSelfReferenced(_sourceBlockHash),
            "Source block is not self referenced."
        );

        require(
            _isSelfReferenced(_targetBlockHash),
            "Target block is not self referenced."
        );
    }

    function _storeAuxiliaryForwardVote(
        address validator,
        bytes32 voteHash,
        bytes32 validatorVoteHash
    )
        internal
    {
        revert("Implementation is missing!");
    }

    function _storeAuxiliaryRearVote(
        address validator,
        bytes32 voteHash,
        bytes32 validatorVoteHash
    )
        internal
    {
        revert("Implementation is missing!");
    }

    /**
     * @notice Stores a validator vote.
     *
     * @dev Function assumes:
     *          - validator's vote has not been already submitted
     */
    function _storeOriginVote(
        address validator,
        bytes32 voteHash,
        bytes32 validatorVoteHash
    )
        internal
    {
        validatorVoteHashes[validatorVoteHash] = true;

        uint256 validatorWeight = _validatorWeight(validator);

        originVoteWeights[voteHash] = originVoteWeights[voteHash].add(
            validatorWeight
        );
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
     *          - the block is a checkpoint
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
     * @dev Function assumes:
     *          - validator is active
     */
    function _belongsToForwardSet(
        address _validatorAddress,
        uint256 _metaBlockHeight
    )
        internal
        returns (bool belongsToForwardSet_)
    {
        revert("Implementation is missing!");
    }

    /**
     * @dev Function assumes:
     *          - validator is active
     */
    function _belongsToRearSet(
        address _validatorAddress,
        uint256 _metaBlockHeight
    )
        internal
        returns (bool belongsToRearSet_)
    {
        revert("Implementation is missing!");
    }

    function _isAuxiliaryForwardQuorumReached(
        bytes32 _voteHash
    )
        internal
        returns (bool)
    {
        revert("Implementation is missing!");
    }

    function _isAuxiliaryRearQuorumReached(
        bytes32 _voteHash
    )
        internal
        returns (bool)
    {
        revert("Implementation is missing!");
    }

    function _validatorWeight(
        address _validator
    )
        internal
        view
        returns (uint256)
    {
        revert("Implementation is missing!");
    }

    /**
     * @notice Calculates a required weight to reach quorum
     *         for the origin chain.
     */
    function _calculateOriginRequiredWeight()
        internal
        view
        returns (uint256 requiredWeight_)
    {
        requiredWeight_ = _calculateSupermajorityValue(
            activeValidatorsSummedWeight
        );
    }

    /**
     * @notice Calculates supermajority value based on the given value.
     *
     * @param _value A base value to calculate supermajority value.
     */
    function _calculateSupermajorityValue(uint256 _value)
        internal
        pure
        returns (uint256 supermajorityValue_)
    {
        supermajorityValue_ = _value * SUPER_MAJORITY_NUMERATOR /
            SUPER_MAJORITY_DENOMINATOR;
    }

    /**
     * @notice Returns the summed weight for a forward validator set of
     *         the given metablock height.
     */
    function _forwardValidatorsSummedWeight(uint256 _metaBlockHeight)
        internal
        view
        returns (uint256 forwardValidatorsSummedWeight_)
    {
        revert("Implementation is missing!");
    }

    /**
     * @notice Returns the summed weight for a rear validator set of
     *         the given metablock height.
     */
    function _rearValidatorsSummedWeight(uint256 _metaBlockHeight)
        internal
        view
        returns (uint256 rearValidatorsSummedWeight_)
    {
        revert("Implementation is missing!");
    }

    /**
     * @notice Returns a metablock height for the given block of the
     *         auxiliary chain.
     *
     * @param _blockHash Hash of the block to retrieve the metablock height.
     *
     * @return metaBlockHeight_ Meta block height for the given block.
     */
    function _metaBlockHeight(bytes32 _blockHash)
        internal
        view
        returns (uint256 metaBlockHeight_)
    {
        revert("Implementation is missing!");
    }

    /**
     * @notice Asserts an inclusion for the specified block.
     *
     * @dev Function assumes
     *          - block is a checkpoint
     */
    function _assertInclusion(
        bytes32 _blockHash
    )
        internal
        view
    {
        revert("Implementation is missing!");
    }

    /**
     * @notice Calculates and rounds the number of epochs between two given
     *         blocks.
     *
     * @dev Function assumes:
     *          - core identifier validity
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
        epochDistance_ = blockDistance.div(epochLengths[_coreIdentifier]);
    }

    /**
     * @notice Hashes vote message.
     *
     * @dev Function assumes:
     *          - core identifier validity
     *
     * @param _coreIdentifier A unique identifier that identifies the chain.
     * @param _transitionHash The hash of the transition object.
     * @param _sourceBlockHash The hash of the source block.
     * @param _targetBlockHash The hash of the target block.
     * @param _sourceBlockHeight The height of the source block.
     * @param _targetBlockHeight The height of the target block.
     *
     * @return voteHash_ Returns vote hash.
     */
    function _hashVoteMessage(
        bytes20 _coreIdentifier,
        bytes32 _transitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        returns (bytes32 voteHash_)
    {
        if (_coreIdentifier == originCoreIdentifier) {
            require(
                _transitionHash == bytes32(0),
                "Transition hash for origin vote should be 0."
            );
            voteHash_ = _hashOriginVoteMessage(
                _sourceBlockHash,
                _targetBlockHash,
                _sourceBlockHeight,
                _targetBlockHeight
            );
        } else if (_coreIdentifier == auxiliaryCoreIdentifier) {
            voteHash_ = _hashAuxiliaryVoteMessage(
                _transitionHash,
                _sourceBlockHash,
                _targetBlockHash,
                _sourceBlockHeight,
                _targetBlockHeight
            );
        } else {
            voteHash_ = bytes32(0);
        }
    }

    /**
     * @notice Hashes origin vote message.
     *
     * @dev Function assumes:
     *          - core identifier validity
     *          - validity of input hashes and heights
     *
     * @param _sourceBlockHash The hash of the source block.
     * @param _targetBlockHash The hash of the target block.
     * @param _sourceBlockHeight The height of the source block.
     * @param _targetBlockHeight The height of the target block.
     *
     * @return voteHash_ Returns origin vote hash.
     */
    function _hashOriginVoteMessage(
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        returns (bytes32 voteHash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                ORIGIN_VOTE_MESSAGE_TYPEHASH,
                originCoreIdentifier,
                _sourceBlockHash,
                _targetBlockHash,
                _sourceBlockHeight,
                _targetBlockHeight
            )
        );

        voteHash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedVoteMessageHash
            )
        );
    }

    /**
     * @notice Hashes auxiliary vote message.
     *
     * @dev Function assumes:
     *          - core identifier validity
     *          - validity of input hashes and heights
     *
     * @param _transitionHash The hash of auxiliary transition object.
     * @param _sourceBlockHash The hash of the source block.
     * @param _targetBlockHash The hash of the target block.
     * @param _sourceBlockHeight The height of the source block.
     * @param _targetBlockHeight The height of the target block.
     *
     * @return voteHash_ Returns auxiliary vote hash.
     */
    function _hashAuxiliaryVoteMessage(
        bytes32 _transitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        returns (bytes32 voteHash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                AUXILIARY_VOTE_MESSAGE_TYPEHASH,
                auxiliaryCoreIdentifier,
                _transitionHash,
                _sourceBlockHash,
                _targetBlockHash,
                _sourceBlockHeight,
                _targetBlockHeight
            )
        );

        voteHash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedVoteMessageHash
            )
        );
    }
}
