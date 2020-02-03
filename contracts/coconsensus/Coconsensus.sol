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
import "../observer/ObserverI.sol";
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


    /* Storage */

    /** Mapping to track the blocks for each metachain. */
    mapping (bytes32 /* metachainId */ => mapping(uint256 /* blocknumber */ => Block)) blockchains;

    /** 
     * Mapping of metachain id to latest block number(tip) stored
     * in blockchains.
     */
    mapping (bytes32 /* metachainId */ => uint256 /* blocknumber */) blockTips;

    /** Mapping of metachain id to the protocore contract address. */
    mapping (bytes32 /* metachainId */ => ProtocoreI) protocores;

    /** Mapping of metachain id to the observers contract address. */
    mapping (bytes32 /* metachainId */ => ObserverI) observers;

    /** Mapping of metachain id to the domain separators. */
    mapping (bytes32 /* metachainId */ => bytes32 /* domain separator */) domainSeparators;


    /* External Functions */

    /**
     * @notice finaliseCheckpoint() function finalises a checkpoint at
     *         a metachain.
     *
     * @param _metachainId A metachain id to finalise a checkpoint.
     * @param _blockNumber A block number of a checkpoint.
     * @param _blockHash A block hash of a checkpoint.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_blockHash` is not 0.
     * \pre `msg.sender` should be the protocore contract.
     * \pre `_blockNumber` must be multiple of epoch length.
     * \pre `_blockNumber` must be greater than the last finalized block number.
     *
     * \post Sets the `blockchains` mapping.
     * \post Sets the `blockTips` mapping.
     * 
     */
    function finaliseCheckpoint(
        bytes32 _metachainId,
        uint256 _blockNumber,
        bytes32 _blockHash
    )
        external
    {
        // Check if the metachain id is not null.
        require(
            _metachainId != bytes32(0),
            "Metachain id must not be null."
        );

        // Check if the blockhash is not null.
        require(
            _blockHash != bytes32(0),
            "Blockhash must not be null."
        );

        // Check if the caller is correct protocore contract address
        ProtocoreI protocore = protocores[_metachainId];
        require(
            msg.sender == address(protocore),
            "Only protocore contract can call this function."
        );

        /*
         * Check if the new block number is greater than the last
         * finalised block number.
         */
        uint256 lastFinalisedBlockNumber = blockTips[_metachainId];
        require(
            _blockNumber > lastFinalisedBlockNumber,
            "The block number of the checkpoint must be greater than the block number of last finalised checkpoint ."
        );

        // Check if the block number is multiple of epoch length.
        uint256 epochLength = protocore.epochLength();
        require(
            (_blockNumber % epochLength) == 0,
            "Block number must be a checkpoint."
        );

        // Store the finalised block in the mapping.
        Block storage finalisedBlock = blockchains[_metachainId][_blockNumber];
        finalisedBlock.blockHash = _blockHash;
        finalisedBlock.commitStatus = CheckpointCommitStatus.Finalized;
        finalisedBlock.statusDynasty = protocore.dynasty();

        // Store the tip.
        blockTips[_metachainId] = _blockNumber;
    }
}
