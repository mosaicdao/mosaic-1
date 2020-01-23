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
        uint256 forwardVoteCount;
        uint256 forwardVoteCountNextHeight;
        uint256 forwardVoteCountPreviousHeight;
        CheckpointFinalisationStatus targetFinalisation;
    }


    /* Storage */

    mapping(bytes32 /* vote message hash */ => Link) public links;

    uint256 public openKernelHeight;
    bytes32 public openKernelHash;

    /** Epoch length */
    uint256 public epochLength;


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

        Link storage parentLink = links[_parentVoteMessageHash];

        require(
            parentLink.targetBlockHash != bytes32(0),
            "Parent link does not exist."
        );

        require(
            parentLink.targetFinalisation >= CheckpointFinalisationStatus.Justified,
            "Parent link's target finalisation status should be at least justified."
        );

        require(
            _targetBlockHash != bytes32(0),
            "Target block hash of the proposed link is 0."
        );

        require(
            _targetBlockNumber % epochLength == 0,
            "Target block number of the link should be multiple of the epoch length."
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
}
