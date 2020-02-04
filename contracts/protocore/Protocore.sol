pragma solidity >=0.5.0 <0.6.0;

// Copyright 2020 OpenST Ltd.
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

import "../consensus/CoconsensusModule.sol";
import "../validator/ForwardValidatorSetAbstract.sol";
import "../validator/ValidatorSet.sol";
import "../version/MosaicVersion.sol";

/**
 * @title Protocore abstract contract acting as a base contract for
 *        OriginProtocore and SelfProtocore contracts.
 */
contract Protocore is MosaicVersion, CoconsensusModule, ForwardValidatorSetAbstract {

    /* Usings */

    using SafeMath for uint256;


    /* Enums */

    enum CheckpointFinalisationStatus {
        Undefined,
        Registered,
        Justified,
        Finalised
    }


    /* Events */

    event KernelOpened(uint256 kernelHeight, bytes32 kernelHash);

    event VoteRegistered(
        bytes32 voteMessageHash,
        uint256 height,
        bytes32 r,
        bytes32 s,
        uint8 v
    );

    event LinkUpvoted(
        bytes32 voteMessageHash,
        CheckpointFinalisationStatus targetFinalisationStatus
    );


    /* Structs */

    struct Link {
        bytes32 parentVoteMessageHash;
        bytes32 targetBlockHash;
        uint256 targetBlockNumber;
        bytes32 sourceTransitionHash;
        uint256 proposedMetablockHeight;
        mapping(uint256 /* height */ => uint256 /* FVS vote count */) fvsVoteCount;
        CheckpointFinalisationStatus targetFinalisation;
    }


    /* Constants */

    /** Defines a super-majority fraction used for reaching consensus. */
    uint256 public constant CORE_SUPER_MAJORITY_NUMERATOR = uint256(2);
    uint256 public constant CORE_SUPER_MAJORITY_DENOMINATOR = uint256(3);

    /** Sentinel pointer for marking end of linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);

    /** EIP-712 type hash for a Vote Message */
    bytes32 public constant VOTE_MESSAGE_TYPEHASH = keccak256(
        "VoteMessage(bytes32 transitionHash,bytes32 sourceBlockHash,bytes32 targetBlockHash,uint256 sourceBlockNumber,uint256 targetBlockNumber)"
    );


    /* Storage */

    /** Metachain id of the metablockchain. */
    bytes32 public metachainId;

    /** Epoch length */
    uint256 public epochLength;

    /** EIP-712 domain separator. */
    bytes32 public domainSeparator;

    uint256 public openKernelHeight;
    bytes32 public openKernelHash;

    mapping(uint256 /* metablock height */ => uint256 /* Quorum */) public fvsQuorums;

    mapping(bytes32 /* vote message hash */ => Link) public links;

    mapping(bytes32 /* vote message hash */ =>
        mapping(uint256 /* metablock height */ =>
            mapping(address => address) /* validators linked list */
        )
    ) public fvsVotes;


    /* Special Functions */

    /**
     * @notice setup() function initializes the current contract.
     *         The function will be called by inherited contracts.
     *
     * @param _metachainId Metachain Id.
     * @param _domainSeparator Domain separator.
     * @param _epochLength Epoch length.
     * @param _metablockHeight Metablock height.
     * @param _genesisParentVoteMessageHash Parent vote message hash for the genesis link.
     * @param _genesisSourceTransitionHash Source transition hash for the genesis link.
     * @param _genesisSourceBlockHash Source blockhash for the genesis link.
     * @param _genesisSourceBlockNumber Source block number for the genesis link.
     * @param _genesisTargetBlockHash Target blockhash for the genesis link.
     * @param _genesisTargetBlockNumber Target block number for the genesis link.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_domainSeparator` is not 0.
     * \pre `_epochLength` is not 0.
     * \pre `_genesisSourceBlockNumber` must be multiple of `_epochLength`.
     * \pre `_genesisTargetBlockNumber` must be multiple of `_epochLength`.
     * \pre `_genesisTargetBlockHash` must not be 0.
     * \pre `_genesisTargetBlockNumber` must be greater than or equal to `_genesisSourceBlockNumber`.
     *
     * \post Sets `domainSeparator` to the given value.
     * \post Sets `epochLength` to the given value.
     * \post Sets `metachainId` to the given value.
     * \post Sets genesis link.
     */
    function setup(
        bytes32 _metachainId,
        bytes32 _domainSeparator,
        uint256 _epochLength,
        uint256 _metablockHeight,
        bytes32 _genesisParentVoteMessageHash,
        bytes32 _genesisSourceTransitionHash,
        bytes32 _genesisSourceBlockHash,
        uint256 _genesisSourceBlockNumber,
        bytes32 _genesisTargetBlockHash,
        uint256 _genesisTargetBlockNumber
    )
        internal
    {
        require(
            metachainId == bytes32(0),
            "Contract is already initialized."
        );
        require(
            _epochLength != 0,
            "Epoch length is 0."
        );
        require(
            _domainSeparator != bytes32(0),
            "Domain separator must not be null."
        );
        require(
            _genesisSourceBlockNumber % _epochLength == 0,
            "Genesis source block number must be multiple of epoch length."
        );
        require(
            _genesisTargetBlockNumber % _epochLength == 0,
            "Genesis target block number must be multiple of epoch length."
        );
        require(
            _genesisTargetBlockHash != bytes32(0),
            "Genesis target block hash must not be null."
        );
        require(
            _genesisTargetBlockNumber >= _genesisSourceBlockNumber,
            "Genesis target block number is less than genesis source block number."
        );

        metachainId = _metachainId;

        domainSeparator = _domainSeparator;

        epochLength = _epochLength;

        // Generate the genesis vote message hash.
        bytes32 genesisVoteMessageHash = hashVoteMessage(
            _genesisSourceTransitionHash,
            _genesisSourceBlockHash,
            _genesisTargetBlockHash,
            _genesisSourceBlockNumber,
            _genesisTargetBlockNumber
        );

        // Store the genesis link.
        Link storage genesisLink = links[genesisVoteMessageHash];
        genesisLink.parentVoteMessageHash = _genesisParentVoteMessageHash;
        genesisLink.targetBlockHash = _genesisTargetBlockHash;
        genesisLink.targetBlockNumber = _genesisTargetBlockNumber;
        genesisLink.sourceTransitionHash = _genesisSourceTransitionHash;
        genesisLink.proposedMetablockHeight = _metablockHeight;
        genesisLink.targetFinalisation = CheckpointFinalisationStatus.Finalised;
    }


    /* External Functions */

    /**
     * @notice openKernel() function marks the specified kernel
     *         as opened.
     *
     * @param _kernelHeight New kernel height.
     * @param _kernelHash New kernel hash.
     *
     * \pre Only coconsensus can call.
     * \pre `_kernelHeight` is plus one of the current kernel height of
     *      the protocore.
     * \pre `_kernelHash` is not 0.
     *
     * \post Increments open kernel height.
     * \post Updates stored open kernel hash.
     * \post Updates forward validator set quorum for the newly opened metablock height.
     */
    function openKernel(
        uint256 _kernelHeight,
        bytes32 _kernelHash
    )
        external
        onlyCoconsensus
    {
        require(
            _kernelHeight == openKernelHeight.add(1),
            "The given kernel height should be plus 1 of the current one."
        );

        require(_kernelHash != bytes32(0), "The given kernel hash is 0.");

        openKernelHeight = _kernelHeight;
        openKernelHash = _kernelHash;

        fvsQuorums[openKernelHeight] = calculateQuorum(
            forwardValidatorCount(openKernelHeight)
        );

        emit KernelOpened(openKernelHeight, openKernelHash);
    }


    /** Internal Functions */

    /**
     * @notice proposeLinkInternal() function proposes a valid link to be
     *         voted later by active validators.
     *
     * \pre `parentVoteMessageHash` is not 0.
     * \pre `parentVoteMessageHash` refers to an already proposed link which
     *      `targetFinalisation` is at least justified.
     * \pre `targetBlockHash` is not 0
     * \pre `targetBlockNumber` is a multiple of the epoch length.
     * \pre `targetBlockNumber` is bigger than a targetBlockNumber pointed
     *      by `_parentVoteMessageHash` link.
     * \pre A vote message hash (calculated with input params) does not exist.
     *
     * \post The link is saved in `links` mapping with currently
     *       open kernel/metablock height as `proposedMetablockHeight`.
     * \post `targetFinalisation` is set to 'Registered'.
     * \post forwardVoteCount -s set to 0.
     */
    function proposeLinkInternal(
        bytes32 _parentVoteMessageHash,
        bytes32 _sourceTransitionHash,
        bytes32 _targetBlockHash,
        uint256 _targetBlockNumber
    )
        internal
    {
        require(
            _parentVoteMessageHash != bytes32(0),
            "Parent vote message hash is 0."
        );

        require(
            _targetBlockHash != bytes32(0),
            "Target block hash of the proposed link is 0."
        );

        require(
            _targetBlockNumber % epochLength == 0,
            "Target block number of the link should be multiple of the epoch length."
        );

        Link storage parentLink = links[_parentVoteMessageHash];

        require(
            parentLink.targetFinalisation >=
                CheckpointFinalisationStatus.Justified,
            "Parent link's target finalisation status should be at least justified."
        );

        require(
            _targetBlockNumber > parentLink.targetBlockNumber,
            "Target block number of the proposed link should be bigger than parent one."
        );

        bytes32 voteMessageHash = hashVoteMessage(
            _sourceTransitionHash,
            parentLink.targetBlockHash,
            _targetBlockHash,
            parentLink.targetBlockNumber,
            _targetBlockNumber
        );

        require(
            links[voteMessageHash].targetBlockHash == bytes32(0),
            "The proposed link already exists."
        );

        Link storage proposedLink = links[voteMessageHash];
        proposedLink.parentVoteMessageHash = _parentVoteMessageHash;
        proposedLink.targetBlockHash = _targetBlockHash;
        proposedLink.targetBlockNumber = _targetBlockNumber;
        proposedLink.sourceTransitionHash = _sourceTransitionHash;
        proposedLink.proposedMetablockHeight = openKernelHeight;
        proposedLink.targetFinalisation = CheckpointFinalisationStatus.Registered;
    }

    /* Private Functions */

    /**
     * @notice registerVoteInternal() function registers a vote for a link
     *         specified by vote message hash.
     *         If a forward validator set for the open metablock height "H" and
     *         a forward validator set for the previous metablock height "H-1"
     *         reach quorum the target checkpoint of the link gets justified.
     *         In addition to the current link's target checkpoint
     *         justification, in case if the link is a finalisation link (a
     *         distance between its source and target checkpoints is exactly
     *         one epoch length) the source checkpoint of the link gets
     *         finalised.
     *         Function also reports to the Coconsensus contract about
     *         finalised source checkpoint of the link.
     *
     *         During a proposal of a link the open metablock height "H" is
     *         stored as a "proposedMetablockHeight" of the link. Validators
     *         register their votes to justify/finalise the link's checkpoints.
     *         Most links get justified/finalised before a new metablock is opened.
     *         However, it's inevitable that
     *         some links are not justified/finalised when a new metablock is opened.
     *         With a new metablock the validator set and quorum changes.
     *         As the change in validator set is stitched with the Forward Validator Set (FVS)
     *         of `H` and `H-1`; the vote count for the FVS(H) can be preserved,
     *         but the quorum is now for FVS(H+1) && FVS(H) when the new metablock is opened.
     *
     *         Validator votes that need to be counted for FVS(H+1) must be re-registered;
     *         double-counting for FVS(H) is accounted for in the implementation.
     *
     * \pre `_voteMessageHash` is not 0.
     * \pre A link mapping to the `_voteMessageHash` exists.
     * \pre A status of a target checkpoint of the given link is "Registered" or higher.
     * \pre The proposed metablock height of the link pointed by
     *      `_voteMessageHash` is equal to the open metablock height or
     *      open metablock height minus 1.
     * \pre The validator has not already voted for the current link at the
     *      current metablock height.
     *
     * \post If quorum reached then for the link pointed by `_voteMessageHash`
     *       targetFinalisation of the target checkpoint is set to justified.
     * \post If the link length is equal to the epoch length (finalisation link)
     *       then marks targetFinalisation of the link pointed by
     *       parentVoteMessageHash of the given link as finalised once quorum
     *       is reached.
     * \post Calls coconsensus if the source checkpoint of the link gets
     *       finalised.
     */
    function registerVoteInternal(
        bytes32 _voteMessageHash,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        internal
    {
        require(
            _voteMessageHash != bytes32(0),
            "Vote message hash is 0."
        );

        Link storage link = links[_voteMessageHash];

        require(
            link.targetFinalisation >= CheckpointFinalisationStatus.Registered,
            "The given link status is at least reported."
        );

        require(
            link.proposedMetablockHeight.add(1) >= openKernelHeight,
            "Link height inclusion principle has surpassed."
        );

        address validator = ecrecover(_voteMessageHash, _v, _r, _s);

        require(
            validator != address(0),
            "Validator must not be null."
        );

        require(
            fvsVotes[_voteMessageHash][openKernelHeight][validator] == address(0),
            "Validator vote cannot be registered twice in FVS votes at the same height."
        );

        bool quorumReached = countVoteForForwardValidatorSets(_voteMessageHash, link, validator);
        insertForwardValidatorVote(_voteMessageHash, validator);

        emit VoteRegistered(_voteMessageHash, openKernelHeight, _r, _s, _v);

        if (quorumReached) {
            justifyLink(_voteMessageHash, link);
        }
    }


    /* Private Functions */

    /**
     * @notice calculateQuorum() function calculates quorum of the given
     *         count.
     *         The super majority numerator and dominator must be the same
     *         as in the corresponding core.
     */
    function calculateQuorum(uint256 _count)
        private
        pure
        returns (uint256 quorum_)
    {
        quorum_ = _count
            .mul(CORE_SUPER_MAJORITY_NUMERATOR)
            .div(CORE_SUPER_MAJORITY_DENOMINATOR);
    }

    function countVoteForForwardValidatorSets(
        bytes32 _voteMessageHash,
        Link storage _link,
        address _validator
    )
        private
        returns (bool quorumReached_)
    {
        if (canVoteInForwardValidatorSet(
            _voteMessageHash,
            openKernelHeight,
            _validator)) {
            _link.fvsVoteCount[openKernelHeight] = _link.fvsVoteCount[openKernelHeight].add(1);
        }
        bool quorumForwardValidatorSet = _link.fvsVoteCount[openKernelHeight] >= fvsQuorums[openKernelHeight];

        bool quorumRearValidatorSet = true;
        if (openKernelHeight > uint256(0)) {
            uint256 previousHeight = openKernelHeight.sub(1);
            if (canVoteInForwardValidatorSet(
                _voteMessageHash,
                previousHeight,
                _validator)) {
                _link.fvsVoteCount[previousHeight] = _link.fvsVoteCount[previousHeight].add(1);
            }

            quorumRearValidatorSet = _link.fvsVoteCount[previousHeight] >= fvsQuorums[previousHeight];
        }

        quorumReached_ = (quorumForwardValidatorSet && quorumRearValidatorSet);
    }

    function canVoteInForwardValidatorSet(
        bytes32 _voteMessageHash,
        uint256 _fvsHeight,
        address _validator
    )
        private
        view
        returns (bool)
    {
        bool hasNotVoted = (fvsVotes[_voteMessageHash][_fvsHeight][_validator] == address(0));
        bool inFvs = inForwardValidatorSet(
            _validator,
            _fvsHeight
        );
        return (hasNotVoted && inFvs);
    }

    function insertForwardValidatorVote(
        bytes32 _voteMessageHash,
        address _validator
    )
        private
    {
        assert(fvsVotes[_voteMessageHash][openKernelHeight][_validator] == address(0));
        address lastValidator = fvsVotes[_voteMessageHash][openKernelHeight][SENTINEL_VALIDATORS];
        // lazy-initialise linked list for forward validator set votes
        if (lastValidator == address(0)) {
            fvsVotes[_voteMessageHash][openKernelHeight][SENTINEL_VALIDATORS] = SENTINEL_VALIDATORS;
            lastValidator = SENTINEL_VALIDATORS;
        }

        fvsVotes[_voteMessageHash][openKernelHeight][_validator] = lastValidator;
        fvsVotes[_voteMessageHash][openKernelHeight][SENTINEL_VALIDATORS] = _validator;
    }

    /**
     * @notice justifyLink() function justifies the target checkpoint of the
     *         given link, finalises the source checkpoint of the given link if
     *         it is a finalisation link, and reports coconsensus about the
     *         finalisation of the checkpint (if applicable). Only executes once
     *         when link goes from Registered to Justified.
     *
     * @dev Function assumes correctness of the link and the fact that
     *      quorum has reached.
     */
    function justifyLink(
        bytes32 _voteMessageHash,
        Link storage _link
    )
        private
    {
        if (_link.targetFinalisation == CheckpointFinalisationStatus.Registered) {
            _link.targetFinalisation = CheckpointFinalisationStatus.Justified;
            emit LinkUpvoted(
                _voteMessageHash,
                CheckpointFinalisationStatus.Justified
            );

            Link storage parentLink = links[_link.parentVoteMessageHash];

            if (_link.targetBlockNumber.sub(parentLink.targetBlockNumber) == epochLength) {
                assert(parentLink.targetFinalisation >= CheckpointFinalisationStatus.Justified);
                parentLink.targetFinalisation = CheckpointFinalisationStatus.Finalised;
                emit LinkUpvoted(
                    _link.parentVoteMessageHash,
                    CheckpointFinalisationStatus.Finalised
                );

                getCoconsensus().finaliseCheckpoint(
                    metachainId,
                    parentLink.targetBlockNumber,
                    parentLink.targetBlockHash
                );
            }
        }
    }

    /**
     * @notice Takes vote message parameters and returns the typed vote
     *         message hash.
     *
     * @param _transitionHash Transition hash.
     * @param _sourceBlockHash Blockhash of source chain.
     * @param _targetBlockHash Blockhash of target chain.
     * @param _sourceBlockNumber Block number at source.
     * @param _targetBlockNumber Block number at target.
     */
    function hashVoteMessage(
        bytes32 _transitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        private
        view
        returns (bytes32 voteMessageHash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                VOTE_MESSAGE_TYPEHASH,
                _transitionHash,
                _sourceBlockHash,
                _targetBlockHash,
                _sourceBlockNumber,
                _targetBlockNumber
            )
        );

        voteMessageHash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedVoteMessageHash
            )
        );
    }
}
