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

    /* External Functions */

    /**
     * @notice Gets the anchor address for a metachain id.
     *
     * @param _metachainId Metachain id.
     *
     * @return Anchor contract address.
     */
    function getAnchor(bytes32 _metachainId) external returns (address);

    /**
     * @notice Finalizes the checkpoint.
     *
     * @param _metachainId Metachain id.
     * @param _number Block number.
     * @param _blockHash Block hash.
     */
    function finalizeCheckPoint(
        bytes32 _metachainId,
        uint256 _number,
        bytes32 _blockHash
    )
        external;

    /**
     * @notice Commits the checkpoint.
     *
     * @param _metachainId Metachain id.
     * @param _kernelHeight Kernel height.
     * @param _updatedValidators Array of updated validators.
     * @param _updatedReputation Array of updated reputation.
     * @param _gasTarget Gas target.
     * @param _transitionHash Transition hash.
     * @param _source Source block hash.
     * @param _target Target block hash.
     * @param _sourceBlockNumber Source block number.
     * @param _targetBlockNumber Target block number.
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
        external;

    /**
     * @notice Decodes the RLP encoded bytes to extract the block number
     *         and state root. Calls anchorStateRoot to store state root.
     *
     * @param _metachainId Metachain id.
     * @param _rlpBlockHeader RLP encoded block header.
     */
    function observeBlock(
        bytes32 _metachainId,
        bytes calldata _rlpBlockHeader
    )
        external;

}
