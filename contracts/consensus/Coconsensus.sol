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

import "../anchor/ObserverI.sol";
import "../block/BlockHeader.sol";
import "../consensus/GenesisCoconsensus.sol";
import "../protocore/ProtocoreI.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../version/MosaicVersion.sol";

/**
 * @title Coconsensus contract - This mirrors the consensus contract on
 *        the auxiliary chain.
 */
contract Coconsensus is MasterCopyNonUpgradable, GenesisCoconsensus, MosaicVersion {

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
    bytes32 public constant SENTINEL_METACHAIN_ID = bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);


    /* Storage */

    /** Metachain id of the origin chain. */
    bytes32 public originMetachainId;

    /** Metachain id of the auxiliary chain (self). */
    bytes32 public selfMetachainId;

    /**
     * Relative self dynasty of self protocore. This will be incremented when the
     * self protocore contract will call `finalizeCheckpoint`
     */
    uint256 public relativeSelfDynasty;

    /** Mapping to track the finalised blocks of each metachain. */
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


    /* Special Functions */

    /**
     * @notice Setup function does the initialization of all the mosaic
     *         contracts on the auxiliary chain.
     *
     * @dev This function can be called only once.
     */
    function setup() public {

        require(
            selfMetachainId == bytes32(0),
            "Coconsensus contract is already initialized."
        );

        originMetachainId = genesisOriginMetachainId;

        selfMetachainId = genesisSelfMetachainId;

        relativeSelfDynasty = uint256(0);

        bytes32 currentMetachainId = genesisMetachainIds[SENTINEL_METACHAIN_ID];

        // Loop through the genesis metachainId link list.
        while (currentMetachainId != SENTINEL_METACHAIN_ID) {

            // Setup protocore contract for the given metachain id.
            setupProtocore(currentMetachainId);

            // Setup observer contract for the given metachain id.
            setupObserver(currentMetachainId);

            // Traverse to next metachain id from the link list mapping.
            currentMetachainId = genesisMetachainIds[currentMetachainId];
        }
    }


    /* External Functions */

    /**
     * @notice Observes the given block by anchoring its state root into the
     *         corresponding observer.
     *
     * @param _metachainId Metachain id.
     * @param _rlpBlockHeader RLP encoded block header.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_rlpBlockHeader` is not 0.
     * \pre `_metachainId` is not `selfMetachainId`.
     * \pre A block must exist in `blockchains` storage for the given
     *      `_metachainid` and block number from the decoded `_rlpBlockHeader`.
     * \pre The commit status of the block must be at least `Finalized`.
     * \pre The status dynasty of the block less than `relativeSelfDynasty`.
     *
     * \post Anchors the state root in the observer contract.
     */
    function observeBlock(
        bytes32 _metachainId,
        bytes calldata _rlpBlockHeader
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id must not be null."
        );

        require(
            _rlpBlockHeader.length != 0,
            "RLP block header must not be null."
        );

        require(
            _metachainId != selfMetachainId,
            "Metachain id must not be self metachain id."
        );

        // Decode the rlp encoded block header.
        BlockHeader.Header memory blockHeader = BlockHeader.decodeHeader(_rlpBlockHeader);

        Block memory finalizedBlock = blockchains[_metachainId][blockHeader.height];

        require(
            finalizedBlock.blockHash == blockHeader.blockHash,
            "Provided block header is not valid."
        );

        require(
            finalizedBlock.commitStatus >= CheckpointCommitStatus.Finalized,
            "Block must be at least finalized."
        );

        require(
            relativeSelfDynasty > finalizedBlock.statusDynasty,
            "Relative self dynasty must be greater than the status dynasty."
        );

        // Get the observer contract.
        ObserverI observer = observers[_metachainId];

        // Anchor the state root.
        observer.anchorStateRoot(blockHeader.height, blockHeader.stateRoot);
    }

    /* Private Functions */

    /**
     * @notice Do the initial setup of protocore contract and initialize the
     *         storage of coconsensus contract.
     *
     * @param _metachainId Metachain id.
     *
     * \pre Protocore contract must exist for given metachain id.
     *
     * \post Adds newly setup protocore's address into protocores storage variable.
     * \post Adds newly setup protocore's domain separator into domainSeparators.
     *       storage variable.
     * \post Adds a new Block into blockchain storage variable.
     * \post Updates blockTips storage variable with the latest finalized
     *       checkpoint's block number of the newly setup protocore.
     */
    function setupProtocore(bytes32 _metachainId) private {

        // Get the protocore contract address from the genesis storage.
        address protocoreAddress = genesisProtocores[_metachainId];

        require(
            protocoreAddress != address(0),
            "Protocore address must not be null."
        );

        // Setup protocore.
        ProtocoreI protocore = ProtocoreI(protocoreAddress);
        ( bytes32 blockHash, uint256 blockNumber ) = protocore.setup();

        // Store the protocore address in protocores mapping.
        protocores[_metachainId] = protocore;

        // Get the domain separator and store it in domainSeparators mapping.
        domainSeparators[_metachainId] = protocore.domainSeparator();

        // Store the block informations in blockchains mapping.
        blockchains[_metachainId][blockNumber] = Block(
            blockHash,
            CheckpointCommitStatus.Finalized,
            relativeSelfDynasty
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
     * /pre Observer contract address must exists for given metachain id in
     *      genesisObservers storage.
     *
     * /post Setup observer contract.
     * /post Adds newly setup observer's address into observers storage variable.
     */
    function setupObserver(bytes32 _metachainId) private {

        // Get the observer contract address from the genesis storage.
        address observerAddress = genesisObservers[_metachainId];
        if(observerAddress != address(0)) {
            // Call the setup function.
            ObserverI observer = ObserverI(observerAddress);
            observer.setup();

            // Update the observers mapping.
            observers[_metachainId] = observer;
        }
    }
}
