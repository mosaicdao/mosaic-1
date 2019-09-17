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

    /** Logs that a block has been reported. */
    event OriginBlockReported(bytes32 blockHash);

    /** Logs that a block has been justified. */
    event OriginBlockJustified(bytes32 blockHash);

    /** Logs that a block has been finalised. */
    event OriginBlockFinalised(bytes32 blockHash);

    /** Logs that a block has been reported. */
    event AuxiliaryBlockReported(bytes32 blockHash);

    /** Logs that a block has been justified. */
    event AuxiliaryBlockJustified(bytes32 blockHash);

    /** Logs that a block has been finalised. */
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

    /** EIP-712 typehash for an auxiliary transition. */
    bytes32 public constant AUXILIARY_TRANSITION_TYPEHASH = keccak256(
        "AuxiliaryTransition(bytes20 coreIdentifier,bytes32 kernelHash,bytes32 originObservation,uint256 dynasty,uint256 accumulatedGas, bytes32 accumulatedTransactionRoot)"
    );

    /** EIP-712 typehash for an auxiliary vote message. */
    bytes32 public constant AUXILIARY_VOTE_MESSAGE_TYPEHASH = keccak256(
        "AuxiliaryVoteMessage(bytes20 coreIdentifier,bytes32 transitionHash,bytes32 source,bytes32 target,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );


    /* Structs */

    struct ValidatorInfo
    {
        uint256 reputation;

        uint256 startDynasty;

        uint256 endDynasty;

        bool isSlashed;
    }

    /** A casper FFG checkpoint. */
    struct Checkpoint
    {
        /** The block hash of the block at this checkpoint. */
        bytes32 blockHash;

        /** The hash of the block of the parent checkpoint (not block) */
        bytes32 parent;

        /** Is true if the checkpoint has been justified. */
        bool justified;

        /** Is true if the checkpoint has been finalised. */
        bool finalised;

        /**
         * The dynasty of block b is the number of finalised checkpoints in the
         * chain from the starting checkpoint to the parent of block b.
         */
        uint256 dynasty;
    }

    struct AuxiliaryTransitionObject
    {
        bytes32 kernelHash;

        bytes32 originLatestObservation;

        uint256 dynasty;

        uint256 accumulatedGas;

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
    bytes32 public domainSeparator;

    /** Origin chain's core identifier. */
    bytes20 internal originCoreIdentifier;

    /** Auxiliary chain's core identifier. */
    bytes20 internal auxiliaryCoreIdentifier;

    /** Epoch length is the number of blocks from one checkpoint to the next. */
    mapping(bytes20 => uint256) internal epochLengths;

    /** A mapping of block hashes to their reported headers. */
    mapping(bytes20 => mapping(bytes32 => Block.Header)) internal reportedBlocks;

    mapping(bytes32 => VoteCount) internal votesCount;

    /** The block hash of the highest finalised checkpoint. */
    mapping(bytes20 => bytes32) internal heads;

    /**
     * A mapping of auxiliary block hashes to their respective transition
     * object components.
     */
    mapping(bytes32 => AuxiliaryTransitionObject) internal auxiliaryTransitionObjects;

    /** Dynasty number of auxiliary blockchain. */
    uint256 internal auxiliaryDynasty;

    /* A mapping from validator addresses to their respective info. */
    mapping(address => ValidatorInfo) internal validators;


    /* Modifiers */

    modifier coreIsKnown(bytes20 coreIdentifier)
    {
        require(
            _isKnownCore(coreIdentifier),
            "The specified core identifier is unknown to the contract."
        );

        _;
    }


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

    function reportOriginBlock(
        bytes calldata _blockHeaderRlp
    )
        external
    {
        Block.Header memory header = Block.decodeHeader(_blockHeaderRlp);

        _reportBlock(originCoreIdentifier, header);

        emit OriginBlockReported(header.blockHash);
    }

    function reportAuxiliaryBlock(
        bytes calldata _blockHeaderRlp
    )
        external
    {
        Block.Header memory header = Block.decodeHeader(_blockHeaderRlp);

        _reportBlock(originCoreIdentifier, header);

        emit AuxiliaryBlockReported(header.blockHash);

        _fillAuxiliaryTransitionObject(header);
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
     * @param _source The hash of any justified checkpoint.
     * @param _target The hash of any checkpoint that is descendent of source.
    //  * @param _sourceHeight The height of a source checkpoint in the
    //  *                      checkpoint tree.
    //  * @param _targetHeight The height of a target checkpoint in the
    //  *                      checkpoint tree.
     * @param _v V of the signature.
     * @param _r R of the signature.
     * @param _s S of the signature.
     */
    function voteOrigin(
        bytes32 _source,
        bytes32 _target,
        // uint256 _sourceHeight,
        // uint256 _targetHeight,
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

        sourceHeight = reportedBlocks[originCoreIdentifier][_source].blockHeight;
        targetHeight = reportedBlocks[originCoreIdentifier][_target].blockHeight;

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
            _isDescendent(
                originCoreIdentifier,
                _source,
                _target
            ),
            "Source is not a descendent of a target."
        );

        require(
            _isDescendent(
                originCoreIdentifier,
                originLatestFinalisedBlockhash,
                _source
            ),
            "Head is not a descendent of a source."
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
        external;

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

    function isOriginBlockReported(
        bytes32 _blockHash
    )
        public
        view
        returns (bool)
    {
        return _isBlockReported(originCoreIdentifier, _blockHash);
    }

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

    function _reportBlock(
        bytes20 _coreIdentifier,
        Block.Header memory header
    )
        internal
        coreIsKnown(_coreIdentifier)
    {
        require(
            _isBlockReported(_coreIdentifier, header.parentHash),
            "The parent of a reported block must be reported first."
        );

        blocks[_coreIdentifier][header.blockHash] = header;
    }

    function _fillAuxiliaryTransitionObject(
        Block.Header memory header
    )
        internal
    {
        Block.Header storage parent = reportedBlocks[header.parentHash];

        auxiliaryTransitionObjects[
            header.blockHash
        ].accumulatedGas = auxiliaryTransitionObjects[
            parent.blockHash
        ].accumulatedGas.add(header.gasUsed);

        auxiliaryTransitionObjects[
            header.blockHash
        ].accumulatedTransactionRoot = keccak256(
            abi.encode(
                auxiliaryTransitionObjects[
                    parent.blockHash
                ].accumulatedTransactionRoot,
                header.transactionRoot
            )
        );

        auxiliaryTransitionObjects[
            header.blockHash
        ].originLatestObservation = originHead;

        auxiliaryTransitionObjects[
            header.blockHash
        ].dynasty = auxiliaryDynasty;
    }

    function _isKnownCore(bytes20 _coreIdentifier)
        internal
        view
        returns(bool)
    {
        return _coreIdentifier == originCoreIdentifier ||
            _coreIdentifier == auxiliaryCoreIdentifier;
    }

    function _isBlockReported(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
        view
        coreIsKnown(_coreIdentifier)
    {
        return reportedBlocks[
            _coreIdentifier
        ][_blockHash].blockHash == _blockHash;
    }

    function _isAtCheckpoint(
        bytes20 _coreIdentifier,
        bytes32 _blockHash
    )
        internal
        view
        coreIsKnown(_coreIdentifier)
        returns (bool atCheckpoint_)
    {
        uint256 blockHeight = reportedBlocks[
            _coreIdentifier
        ][_blockHash].height;

        atCheckpoint_ = _isAtCheckpointHeight(
            _coreIdentifier,
            blockHeight
        );
    }

    /**
     * @notice Returns true if the given height corresponds to a valid
     *         checkpoint height (multiple of the epoch length).
     *
     * @param _height The block height to check.
     *
     * @return true if the given block height is at a valid height.
     */
    function _isAtCheckpointHeight(
        bytes20 _coreIdentifier,
        uint256 _height
    )
        internal
        view
        coreIsKnown(_coreIdentifier)
        returns (bool atCheckpointHeight_)
    {
        atCheckpointHeight_ = _height.mod(epochLengths[_coreIdentifier]) == 0;
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

    function _justify() internal;

    function _finalise() internal;

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
