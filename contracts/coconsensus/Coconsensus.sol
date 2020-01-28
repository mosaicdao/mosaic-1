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
import "../protocore/Protocore.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../version/MosaicVersion.sol";

/**
 * @title Coconsensus contract - This mirrors the consensus contract on the auxiliary chain.
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
    //address public constant SENTINEL_METACHAIN_ID = bytes32(0x1);


    /* Storage */

    /** Mapping to track the blocks for each metachain. */
    mapping (bytes32 /* metachainid */ => mapping(uint256 /* blocknumber */ => Block)) blockchains;

    /** Mapping of metachain id to latest block number(tip) stored in blockchains. */
    mapping (bytes32 /* metachainId */ => uint256 /* blocknumber */) blockTips;

    /** Mapping of metachain id to the protocore contract address. */
    mapping (bytes32 /* metachainId */ => Protocore) protocores;

    /** Mapping of metachain id to the domain separators. */
    mapping (bytes32 /* metachainId */ => bytes32 /* domain separator */) domainSeparators;


    /* External Functions */

    /**
     * Setup function does the initialization of all the mosaic contracts on the auxiliary chain.
     *
     * @dev This function can be called only once.
     */
    function setup() external {
        // bytes32 currentMetachainId = genesisMetachainIds[SENTINEL_METACHAIN_ID];
        // while (currentMetachainId != SENTINEL_METACHAIN_ID) {
        //     setupObservers(currentMetachainId);
        //     setupProtocores(currentMetachainId);
        // }
    }

    // function setupProtocores(bytes32 _metachainId) private {
    //     Protocore protocore = Protocore(genesisProtocores[_metachainId]);
    //     protocore.setup();
    // }

    // function setupObservers(bytes32 _metachainId) private {

    // }
}
