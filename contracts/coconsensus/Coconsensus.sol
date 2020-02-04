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

import "../coconsensus/GenesisCoconsensus.sol";
import "../consensus-gateway/ConsensusCogatewayI.sol";
import "../kernel/Kernel.sol";
import "../observer/ObserverI.sol";
import "../protocore/ProtocoreI.sol";
import "../protocore/SelfProtocoreI.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../reputation/CoreputationI.sol";
import "../version/MosaicVersion.sol";
import "../vote-message/VoteMessage.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title Coconsensus contract - This mirrors the consensus contract on
 *        the auxiliary chain.
 */
contract Coconsensus is 
    MasterCopyNonUpgradable,
    GenesisCoconsensus,
    Kernel,
    VoteMessage,
    MosaicVersion
{

    /* Usings */

    using SafeMath for uint256;


    /* Enums */

    /** Enum for status of committed checkpoint. */
    enum CheckpointCommitStatus {
        Undefined,
        Committed,
        Finalized
    }


    /* Structs */

    /** Struct to track dynasty and checkpoint commit status of a block. */
    struct Block {
        bytes32 blockHash;
        CheckpointCommitStatus commitStatus;
        uint256 statusDynasty;
    }


    /* Constants */

    /**
     * Sentinel pointer for marking the ending of circular,
     * linked-list of genesis metachain ids.
     */
    bytes32 public constant SENTINEL_METACHAIN_ID = bytes32(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );


    /* Storage */

    /** Metachain id of the origin chain. */
    bytes32 public originMetachainId;

    /** Metachain id of the auxiliary chain. */
    bytes32 public auxiliaryMetachainId;

    /** Mapping to track the blocks for each metachain. */
    mapping (bytes32 /* metachainId */ =>
        mapping(uint256 /* blocknumber */ => Block)
    ) public blockchains;

    /**
     * Mapping of metachain id to latest block number(tip) stored
     * in blockchains.
     */
    mapping (bytes32 /* metachainId */ => uint256 /* blocknumber */) public blockTips;

    /** Mapping of metachain id to the protocore contract address. */
    mapping (bytes32 /* metachainId */ => ProtocoreI) public protocores;

    /** Mapping of metachain id to the observers contract address. */
    mapping (bytes32 /* metachainId */ => ObserverI) public observers;

    /** Mapping of metachain id to the domain separators. */
    mapping (bytes32 /* metachainId */ => bytes32 /* domain separator */) public domainSeparators;

    /** Coreputation contract address. */
    CoreputationI private COREPUTATION = address(
        0x0000000000000000000000000000000000004D01
    );

    /** Consensus cogateway contract address. */
    ConsensusCogatewayI private CONSENSUS_COGATEWAY = address(
        0x0000000000000000000000000000000000004D02
    );


    /* Special Functions */

    /**
     * @notice Setup function does the initialization of all the mosaic
     *         contracts on the auxiliary chain.
     *
     * @dev This function can be called only once.
     */
    function setup() public {

        require(
            originMetachainId == bytes32(0),
            "Coconsensus contract is already initialized."
        );

        originMetachainId = genesisOriginMetachainId;
        auxiliaryMetachainId = genesisAuxiliaryMetachainId;

        bytes32 currentMetachainId = genesisMetachainIds[SENTINEL_METACHAIN_ID];

        // Loop through the genesis metachainId link list.
        while (currentMetachainId != SENTINEL_METACHAIN_ID) {

            // Setup observer contract for the given metachain id.
            setupObservers(currentMetachainId);

            // Setup protocore contract for the given metachain id.
            setupProtocores(currentMetachainId);

            // Traverse to next metachain id from the link list mapping.
            currentMetachainId = genesisMetachainIds[currentMetachainId];
        }
    }


    /* External Functions */

    /**
     * @notice Updates the validator set and its reputations with opening of
     *         a new metablock.
     *
     * @param _metachainId Metachain Id.
     * @param _kernelHeight New kernel height
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock
     * @param _transitionHash Transition hash.
     * @param _source Blockhash of source checkpoint.
     * @param _target Blockhash of target checkpoint.
     * @param _sourceBlockNumber Block number of source checkpoint.
     * @param _targetBlockNumber Block number af target checkpoint.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_source` is not 0.
     * \pre `_target` is not 0.
     * \pre `_sourceBlockNumber` is a checkpoint.
     * \pre `_targetBlockNumber` is a checkpoint.
     * \pre `_targetBlockNumber` is greater than `_sourceBlockNumber`.
     * \pre Source checkpoint must be finalized.
     *
     * \pre Open kernel hash must exist in `ConsensusCogateway` contract.
     * \post Update the validator set in self protocore.
     * \post Update the reputation of validators.
     * \post Open a new metablock in self protocore.
     */
    function commitCheckpoint(
        bytes32 _metachainId,
        uint256 _kernelHeight,
        address[] calldata _updatedValidators,
        uint256[] calldata _updatedReputation,
        uint256 _gasTarget,
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id must not be null."
        );
        require(
            _source != bytes32(0),
            "Source blockhash must not be null."
        );
        require(
            _target != bytes32(0),
            "Target blockhash must not be null."
        );

        ProtocoreI protocore = protocores[_metachainId];
        uint256 epochLength = protocore.epochLength();
        require(
            _sourceBlockNumber % epochLength == 0,
            "Source block number must be a checkpoint."
        );
        require(
            _targetBlockNumber % epochLength == 0,
            "Target block number must be a checkpoint."
        );
        require(
            _targetBlockNumber > _sourceBlockNumber,
            "Target block number must be greater than source block number."
        );

        Block storage blockStatus = blockchains[_metachainId][_sourceBlockNumber];
        require(
            blockStatus.commitStatus == CheckpointCommitStatus.Finalized,
            "Source checkpoint must be finalized."
        );

        blockStatus.commitStatus = CheckpointCommitStatus.Committed;

        bytes32 domainSeparator = protocore.domainSeparators(_metachainId);
        bytes32 metablockHash = VoteMessage.hashVoteMessage(
            _transitionHash,
            _source,
            _target,
            _sourceBlockNumber,
            _targetBlockNumber,
            domainSeparator
        );

        bytes32 calculatedKernelHash = Kernel.hashKernel(
            _kernelHeight,
            metablockHash,
            _updatedValidators,
            _updatedReputation,
            _gasTarget,
            domainSeparator
        );

        ConsensusCogatewayI consensusCogateway = getConsensusCogateway();
        bytes32 openKernelHash = consensusCogateway.getOpenKernelHash(_kernelHeight);

        require(
            calculatedKernelHash == openKernelHash,
            "Calculated kernel hash is not equal to open kernel hash."
        );

        SelfProtocoreI selfProtocore = SelfProtocoreI(address(protocore));        
        CoreputationI coreputation = getCoreputation();

        for (uint256 i = 0; i < _updatedValidators.length; i = i.add(1)) {
            address validator = _updatedValidators[i];
            uint256 reputation = _updatedReputation[i];
            coreputation.upsertValidator(validator, reputation);

            selfProtocore.upsertValidator(
                validator,
                _kernelHeight,
                reputation
            );
        }

        selfProtocore.openMetablock(_kernelHeight, openKernelHash);
    }


    /* Internal Functions */

    /** @notice Get the coreputation contract address. */
    function getCoreputation()
        internal
        view
        returns (CoreputationI)
    {
        return CoreputationI(COREPUTATION);
    }

    /** @notice Get the consensus cogateway contract address. */
    function getConsensusCogateway()
        internal
        view
        return (ConsensusCogatewayI)
    {
        return ConsensusCogatewayI(CONSENSUS_COGATEWAY);
    }

    /* Private Functions */

    /**
     * @notice Do the initial setup of protocore contract and initialize the
     *         storage of coconsensus contract.
     *
     * @param _metachainId Metachain id
     *
     * /pre `protocoreAddress` is not 0
     *
     * /post Setup protocore contract.
     * /post Set `protocores` mapping with the protocore address.
     * /post Set `domainSeparators` mapping with domain separator.
     * /post Set `blockchains` mapping with Block object.
     * /post Set `blockTips` mapping with the block number.
     */
    function setupProtocores(bytes32 _metachainId) private {

        // Get the protocore contract address from the genesis storage.
        address protocoreAddress = genesisProtocores[_metachainId];

        require(
            protocoreAddress != address(0),
            "Protocore address must not be null."
        );

        // Setup protocore.
        ProtocoreI protocore = ProtocoreI(protocoreAddress);
        protocore.setup();

        // Store the protocore address in protocores mapping.
        protocores[_metachainId] = protocore;

        // Get the domain separator and store it in domainSeparators mapping.
        domainSeparators[_metachainId] = protocore.domainSeparator();

        // Get metablock height, block number and block hash of the genesis link.
        (
            uint256 metablockHeight,
            uint256 blockNumber,
            bytes32 blockHash
        ) = protocore.latestFinalizedBlock();

        // Store the block informations in blockchains mapping.
        blockchains[_metachainId][blockNumber] = Block(
            blockHash,
            CheckpointCommitStatus.Finalized,
            metablockHeight
        );

        // Store the blocknumber as tip.
        blockTips[_metachainId] = blockNumber;
    }

    /**
     * @notice Do the initial setup of observer contract and initialize the
     *         storage of coconsensus contract.
     *
     * @param _metachainId Metachain id
     *
     * /pre `observerAddress` is not 0
     *
     * /post Setup observer contract.
     * /post Set `observers` mapping with the observer address.
     */
    function setupObservers(bytes32 _metachainId) private {

        // Get the observer contract address from the genesis storage.
        address observerAddress = genesisObservers[_metachainId];
        require(
            observerAddress != address(0),
            "Observer address must not be null."
        );

        // Call the setup function.
        ObserverI observer = ObserverI(observerAddress);
        observer.setup();

        // Update the observers mapping.
        observers[_metachainId] = observer;
    }
}
