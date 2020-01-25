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
import "../validator/ValidatorSet.sol";
import "../version/MosaicVersion.sol";

/**
 * @title Protocore abstract contract acting as a base contract for
 *        OriginProtocore and SelfProtocore contracts.
 */
contract Protocore is MosaicVersion, ValidatorSet, CoconsensusModule {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    event KernelOpened (
        uint256 kernelHeight,
        bytes32 kernelHash
    );


    /* Enums */

    enum CheckpointFinalisationStatus {
        Undefined,
        Registered,
        Justified,
        Finalised
    }


    /* Structs */

    struct Link {
        bytes32 parentVoteMessageHash;
        bytes32 targetBlockHash;
        uint256 targetBlockNumber;
        bytes32 sourceTransitionHash;
        uint256 proposedMetablockHeight;
        uint256 forwardVoteCountNextHeight;
        uint256 forwardVoteCount;
        uint256 forwardVoteCountPreviousHeight;
        CheckpointFinalisationStatus targetFinalisation;
    }

    struct Quorum {
        uint256 previousForward;
        uint256 forward;
    }


    /* Constants */

    /** Defines a super-majority fraction used for reaching consensus. */
    uint256 public constant CORE_SUPER_MAJORITY_NUMERATOR = uint256(2);
    uint256 public constant CORE_SUPER_MAJORITY_DENOMINATOR = uint256(3);

    /** Sentinel pointer for marking end of linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);


    /* Storage */

    /** Metachain id of the meta-blockchain. */
    bytes32 public metachainId;

    /** Epoch length */
    uint256 public epochLength;

    uint256 public openKernelHeight;
    bytes32 public openKernelHash;

    mapping(uint256 /* metablock height */ => Quorum) public quorums;

    mapping(bytes32 /* vote message hash */ => Link) public links;

    mapping(bytes32 /* vote message hash */ =>
        mapping(uint256 /* metablock height */ =>
            mapping(address => address) /* validators linked list */
        )
    ) public validatorVotes;


    /* Special Functions */

    /**
     * @notice setup() function initializes the current contract.
     *         The function will be called by inherited contracts.
     *
     * \pre `_epochLength` is not 0.
     *
     * \post Sets epochLenght to the given value.
     */
    function setup(
        uint256 _epochLength
    )
        internal
    {
        require(
            _epochLength != 0,
            "Epoch length is 0."
        );

        epochLength = _epochLength;
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
     * \post Updates rear/forward quorums for the newly opened metablock height.
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

        require(
            _kernelHash != bytes32(0),
            "The given kernel hash is 0."
        );

        openKernelHeight = openKernelHeight.add(1);
        openKernelHash = _kernelHash;

        Quorum storage quorum = quorums[openKernelHeight];
        quorum.previousForward = calculateQuorum(forwardValidatorCount(openKernelHeight.sub(1)));
        quorum.forward = calculateQuorum(forwardValidatorCount(openKernelHeight));

        emit KernelOpened(
            openKernelHeight,
            openKernelHash
        );
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
            parentLink.targetFinalisation >= CheckpointFinalisationStatus.Justified,
            "Parent link's target finalisation status should be at least justified."
        );

        require(
            _targetBlockNumber > parentLink.targetBlockNumber,
            "Target block number of the proposed link should be bigger than parent one."
        );

        bytes32 voteMessageHash = hashVoteMessageInternal(
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
     *         A "happy"/"normal" path is when the link gets justified/finalised
     *         before a new metablock is opened. However, it's viable that
     *         a link is not justified/finalised (however, contains some
     *         votes from validators) and metablock height is progressing
     *         to "H+1". We call those links: "hot-links". Implementation
     *         keeps votes of validators that were included in forward
     *         validator set of the metablock height "H" as those votes are
     *         valid votes for the progressed metablock height "H+1".
     *         Validators whose votes were included in this set should
     *         re-register their votes for the same link, however, already
     *         at the new (progressed) metablock height. Implementation will
     *         take care to exclude double voting for the above mentioned
     *         validator set.
     *
     * \pre `_voteMessageHash` is not 0.
     * \pre A link mapping to the `_voteMessageHash` exists.
     * \pre A status of a target checkpoint of the given link is "Registered".
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
            link.targetFinalisation == CheckpointFinalisationStatus.Registered,
            "The given link status is not reported."
        );

        address validator = ecrecover(_voteMessageHash, _v, _r, _s);

        require(
            validatorVotes[_voteMessageHash][openKernelHeight][validator] == address(0),
            "Validator has already registered a vote at this metablock height."
        );
        insertValidatorVote(_voteMessageHash, openKernelHeight, validator);

        if (link.proposedMetablockHeight == openKernelHeight) {
            registerVoteForNonProgressedMetablockHeight(link, validator);
        } else if (link.proposedMetablockHeight.add(1) == openKernelHeight) {
            registerVoteForProgressedMetablockHeight(_voteMessageHash, link, validator);
        } else {
            revert(
                "Metablock height should be equal to the open kernel height or minus 1."
            );
        }
    }

    /**
     * @notice Takes vote message parameters and returns the typed vote
     *         message hash.
     */
    function hashVoteMessageInternal(
        bytes32 _sourceTransitionHash,
        bytes32 _sourceBlockHash,
        bytes32 _targetBlockHash,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        internal
        view
        returns (bytes32 voteMessageHash_);


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

    function insertValidatorVote(
        bytes32 _voteMessageHash,
        uint256 _height,
        address _validator
    )
        private
    {
        address lastValidator = validatorVotes[_voteMessageHash][_height][SENTINEL_VALIDATORS];
        if (lastValidator == address(0)) {
            validatorVotes[_voteMessageHash][_height][SENTINEL_VALIDATORS] = SENTINEL_VALIDATORS;
        }

        validatorVotes[_voteMessageHash][_height][_validator] = lastValidator;
        validatorVotes[_voteMessageHash][_height][SENTINEL_VALIDATORS] = _validator;
    }

    function registerVoteForNonProgressedMetablockHeight(
        Link storage _link,
        address _validator
    )
        private
    {
        bool isInPreviousForwardValidatorSet = inForwardValidatorSet(
            _validator,
            openKernelHeight.sub(1)
        );

        if (isInPreviousForwardValidatorSet) {
            _link.forwardVoteCountPreviousHeight = _link.forwardVoteCountPreviousHeight.add(1);
        }

        bool isInForwardValidatorSet = inForwardValidatorSet(
            _validator,
            openKernelHeight
        );

        if (isInForwardValidatorSet) {
            _link.forwardVoteCount = _link.forwardVoteCount.add(1);
        }

        Quorum storage quorum = quorums[openKernelHeight];

        bool hasQuorumReached = _link.forwardVoteCountPreviousHeight >= quorum.previousForward &&
            _link.forwardVoteCount >= quorum.forward;

        if (hasQuorumReached)
        {
            processLink(_link);
        }
    }

    function registerVoteForProgressedMetablockHeight(
        bytes32 _voteMessageHash,
        Link storage _link,
        address _validator
    )
        private
    {
        bool isInPreviousForwardValidatorSet = inForwardValidatorSet(
            _validator,
            openKernelHeight.sub(1)
        );

        // Checking if the validator has voted for the link in the previous
        // metablock height (no need to check if it was part of the forward
        // validator set on the previous metablock height, as if it's part
        // of the previous metablock height for the currently opened
        // metablock height already satisfies that condition).
        // If both conditions are true, it means validator vote is already
        // counted in this set and should be excluded to avoid double voting.
        if (isInPreviousForwardValidatorSet &&
            validatorVotes[_voteMessageHash][openKernelHeight.sub(1)][_validator] != address(0))
        {
            _link.forwardVoteCount = _link.forwardVoteCount.add(1);
        }

        bool isInForwardValidatorSet = inForwardValidatorSet(
            _validator,
            openKernelHeight
        );

        if (isInForwardValidatorSet) {
            _link.forwardVoteCountNextHeight = _link.forwardVoteCountNextHeight.add(1);
        }

        Quorum storage quorum = quorums[openKernelHeight];

        bool hasQuorumReached = _link.forwardVoteCount >= quorum.previousForward &&
            _link.forwardVoteCountNextHeight >= quorum.forward;

        if (hasQuorumReached)
        {
            processLink(_link);
        }
    }

    /**
     * @notice processLink() function justifies the target checkpoint of the
     *         given link, finalises the source checkpoint of the given link if
     *         it is a finalisation link, and reports coconsensus about the
     *         finalisation of the checkpint (if applicable).
     *
     * @dev Function assumes correctness of the link and the fact that
     *      quorum has reached.
     */
    function processLink(
        Link storage _link
    )
        private
    {
        _link.targetFinalisation = CheckpointFinalisationStatus.Justified;

        Link storage parentLink = links[_link.parentVoteMessageHash];

        if (_link.targetBlockNumber.sub(parentLink.targetBlockNumber) == epochLength) {
            parentLink.targetFinalisation = CheckpointFinalisationStatus.Finalised;

            getCoconsensus().finaliseCheckpoint(
                metachainId,
                parentLink.targetBlockNumber,
                parentLink.targetBlockHash
            );
        }
    }
}
