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
import "../../protocore/OriginProtocore.sol";

contract TestOriginProtocore is OriginProtocore {

    /* Storage */

    CoconsensusI public coconsensus;

    function setCoconsensus(address _coconsensus) external {
        coconsensus = CoconsensusI(_coconsensus);
    }

    function setGenesisStorage(
        bytes32 _genesisMetachainId,
        bytes32 _genesisDomainSeparator,
        uint256 _genesisEpochLength,
        uint256 _genesisProposedMetablockHeight,
        address _genesisSelfProtocore,
        bytes32 _genesisOriginParentVoteMessageHash,
        bytes32 _genesisOriginSourceBlockHash,
        uint256 _genesisOriginSourceBlockNumber,
        bytes32 _genesisOriginTargetBlockHash,
        uint256 _genesisOriginTargetBlockNumber
    )
        external
    {
        genesisMetachainId = _genesisMetachainId;
        genesisDomainSeparator = _genesisDomainSeparator;
        genesisEpochLength = _genesisEpochLength;
        genesisProposedMetablockHeight = _genesisProposedMetablockHeight;
        genesisSelfProtocore = _genesisSelfProtocore;
        genesisOriginSourceBlockHash = _genesisOriginSourceBlockHash;
        genesisOriginSourceBlockNumber = _genesisOriginSourceBlockNumber;
        genesisOriginTargetBlockHash = _genesisOriginTargetBlockHash;
        genesisOriginTargetBlockNumber = _genesisOriginTargetBlockNumber;
        genesisOriginParentVoteMessageHash = _genesisOriginParentVoteMessageHash;
    }

    function getCoconsensus()
		public
		view
		returns (CoconsensusI)
	{
        return coconsensus;
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
}
