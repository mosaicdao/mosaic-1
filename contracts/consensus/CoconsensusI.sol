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

/**
 * @title CoconsensusI.
 *
 * @notice Interface for Coconsensus contract.
 */
interface CoconsensusI {

    /**
     * @notice Gets the anchor address for an metachain id.
     *
     * @return Anchor contract address.
     */
    function getAnchor(bytes32 _metachainId) external returns(address);

    /**
     * @notice finaliseCheckpoint() function finalises a checkpoint at
     *         a metachain.
     *
     * @param _metachainId A metachain id to finalise a checkpoint.
     * @param _blockNumber A block number of a checkpoint.
     * @param _blockHash A block hash of a checkpoint.
     */
    function finaliseCheckpoint(
        bytes32 _metachainId,
        uint256 _blockNumber,
        bytes32 _blockHash
    )
        external;
}

