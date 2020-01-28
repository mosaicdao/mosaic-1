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
import "../version/MosaicVersion.sol";

/**
 * @title Protocore abstract contract acting as a base contract for
 *        OriginProtocore and SelfProtocore contracts.
 */
contract Protocore is MosaicVersion, CoconsensusModule {

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


    /* Constants */

    /** EIP-712 type hash for a Vote Message */
    bytes32 public constant VOTE_MESSAGE_TYPEHASH = keccak256(
        "VoteMessage(bytes32 transitionHash,bytes32 sourceBlockHash,bytes32 targetBlockHash,uint256 sourceBlockNumber,uint256 targetBlockNumber)"
    );


    /* Storage */

    mapping(bytes32 /* vote message hash */ => Link) public links;

    /** EIP-712 domain separator. */
    bytes32 public domainSeparator;

    /** Metachain Id */
    bytes32 public metachainId;

    uint256 public openKernelHeight;
    bytes32 public openKernelHash;

    /** Epoch length */
    uint256 public epochLength;


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

    /**
     * @notice Insert or remove validator. It inserts validator if not already
     *         present and reputation is greater than 0. It removes validator
     *         if it is present and reputation is 0.
     *
     * @dev Function requires:
     *      - Caller should be Coconsensus contract.
     *      - Validator must enter at height equal to current open kernel height.
     *
     * @param _validator Validator address to upsert.
     * @param _height Validator start or end height to be updated.
     * @param _reputation Validator's reputation value.
     */
    function upsertValidator(
        address _validator,
        uint256 _height,
        uint256 _reputation
    )
        external
        onlyCoconsensus
    {
        require(
            _height == openKernelHeight,
            "Validator must enter at height equal to current open kernel height."
        );
        if(ValidatorSet.inValidatorSet(_validator, _height)) {
            if(_reputation == 0) {
                removeValidatorInternal(_validator, _height);
            }
        }
        else {
            if(_reputation > 0) {
                insertValidatorInternal(_validator, _height);
            }
        }
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
