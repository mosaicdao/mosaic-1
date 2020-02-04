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

import "../../consensus/CoconsensusI.sol";
import "../../protocore/SelfProtocore.sol";

contract TestSelfProtocore is SelfProtocore {

    /* Storage */

    CoconsensusI public coconsensus;

    function setCoconsensus(address _coconsensus) external {
        coconsensus = CoconsensusI(_coconsensus);
    }

    function setOpenKernelHeight(uint256 _openKernelHeight) external {
        openKernelHeight = _openKernelHeight;
    }

    function setGenesisStorage(
        bytes32 _genesisAuxiliaryMetachainId,
        bytes32 _genesisDomainSeparator,
        uint256 _genesisEpochLength,
        uint256 _genesisDynasty,
        uint256 _genesisMetablockHeight,
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
        genesisAuxiliaryMetachainId = _genesisAuxiliaryMetachainId;
        genesisDomainSeparator = _genesisDomainSeparator;
        genesisEpochLength = _genesisEpochLength;
        genesisDynasty = _genesisDynasty;
        genesisMetablockHeight = _genesisMetablockHeight;
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
		returns (CoconsensusI)
	{
        return coconsensus;
    }

    /** @notice Set the dynasty for the testing purpose */
    function setDynasty(uint256 _dynasty) external {
        dynasty = _dynasty;
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
}
