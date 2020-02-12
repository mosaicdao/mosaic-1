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

/**
 * @title Interface of Coconsensus contract.
 *
 * @notice Specifies Coconsensus external interfaces to be called from
 *         other parts.
 */
interface CoconsensusI {

    /* External Functions */

    /**
     * @notice Gets the anchor address for a metachain id.
     *
     * @param _metachainId A metachain id of an anchor to retrieve.
     *
     * @return anchor_ An anchor contract's address matching to the
     *                 given metachain id.
     */
    function getAnchor(bytes32 _metachainId) external returns (address anchor_);

    /**
     * @notice finaliseCheckpoint() function finalises a checkpoint of
     *         a metachain.
     *
     * @param _metachainId A metachain id to finalize a checkpoint.
     * @param _blockNumber A block number of a checkpoint to finalize.
     * @param _blockHash A block hash of a checkpoint to finalize.
     */
    function finaliseCheckpoint(
        bytes32 _metachainId,
        uint256 _blockNumber,
        bytes32 _blockHash
    )
        external;
}
