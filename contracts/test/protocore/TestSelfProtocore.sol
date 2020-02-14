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

import "../../consensus/CoconsensusInterface.sol";
import "../../protocore/SelfProtocore.sol";


/**
 * @title TestSelfProtocore
 *
 * @notice It is used to test SelfProtocore contract.
 */
contract TestSelfProtocore is SelfProtocore {

    /* Storage */

    CoconsensusInterface public coconsensus;


    /* External Functions */

    /**
     * @notice It is used to set coconsensus for testing purpose for calling setup
     *         of SelfProtocore contract.
     */
    function setCoconsensus(address _coconsensus) external {
        coconsensus = CoconsensusInterface(_coconsensus);
    }

    /**
     * @notice It is used to set open kernel hash.
     */
    function setOpenKernelHash(bytes32 _openKernelHash) external {
        openKernelHash = _openKernelHash;
    }

    /**
     * @notice It is used to set current open kernel height.
     */
    function setOpenKernelHeight(uint256 _openKernelHeight) external {
        openKernelHeight = _openKernelHeight;
    }

    function setGenesisStorage(
        bytes32 _genesisMetachainId,
        bytes32 _genesisDomainSeparator,
        uint256 _genesisEpochLength,
        uint256 _genesisDynasty,
        uint256 _genesisProposedMetablockHeight,
        bytes32 _genesisAuxiliaryParentVoteMessageHash,
        bytes32 _genesisAuxiliarySourceTransitionHash,
        bytes32 _genesisAuxiliarySourceBlockHash,
        uint256 _genesisAuxiliarySourceBlockNumber,
        bytes32 _genesisAuxiliaryTargetBlockHash,
        uint256 _genesisAuxiliaryTargetBlockNumber,
        uint256 _genesisAuxiliaryAccumulatedGas
    )
        external
    {
        genesisMetachainId = _genesisMetachainId;
        genesisDomainSeparator = _genesisDomainSeparator;
        genesisEpochLength = _genesisEpochLength;
        genesisDynasty = _genesisDynasty;
        genesisProposedMetablockHeight = _genesisProposedMetablockHeight;
        genesisAuxiliaryParentVoteMessageHash = _genesisAuxiliaryParentVoteMessageHash;
        genesisAuxiliarySourceTransitionHash = _genesisAuxiliarySourceTransitionHash;
        genesisAuxiliarySourceBlockHash = _genesisAuxiliarySourceBlockHash;
        genesisAuxiliarySourceBlockNumber = _genesisAuxiliarySourceBlockNumber;
        genesisAuxiliaryTargetBlockHash = _genesisAuxiliaryTargetBlockHash;
        genesisAuxiliaryTargetBlockNumber = _genesisAuxiliaryTargetBlockNumber;
        genesisAuxiliaryAccumulatedGas = _genesisAuxiliaryAccumulatedGas;
    }

    function getCoconsensus()
		public
		view
		returns (CoconsensusInterface)
	{
        return coconsensus;
    }

    /**
     * @notice This function is used to test the
     *         `Coconsensus::finaliseCheckpoint`, the msg.sender for the
     *         `Coconsensus::finaliseCheckpoint` can only be protocore.
     */
    function testFinaliseCheckpoint(
        bytes32 _metachainId,
        uint256 _blockNumber,
        bytes32 _blockHash
    )
        external
    {
        getCoconsensus().finaliseCheckpoint(
            _metachainId,
            _blockNumber,
            _blockHash
        );
    }

    function fvsVoteCount(
        bytes32 _voteMessageHash,
        uint256 _height
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].fvsVoteCount[_height];
    }

    /**
     * @notice It is used to call `incrementActiveHeightInternal`to increment
     *         active height.
     */
    function incrementActiveHeight(uint256 _nextHeight) external {
        ValidatorSet.incrementActiveHeightInternal(_nextHeight);
    }

    function setLink(
        bytes32 _voteMessageHash,
        uint256 _targetBlockNumber,
        uint256 _epochLength
    )
        external
    {
        Link storage link = links[_voteMessageHash];
        link.targetBlockNumber = _targetBlockNumber;
        link.targetFinalisation = CheckpointFinalisationStatus.Registered;
        link.proposedMetablockHeight = openKernelHeight;
        epochLength = _epochLength;
    }
}
