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
import "../../protocore/Protocore.sol";

contract TestProtocore is Protocore {

	/* Storage */

    CoconsensusI public coconsensus;


    /* Special Functions */

    constructor(
        CoconsensusI _coconsensus,
        bytes32 _metachainId,
        bytes32 _domainSeparator,
        uint256 _epochLength,
        uint256 _genesisDynasty,
        uint256 _genesisKernelHeight,
        bytes32 _genesisKernelHash,
        bytes32 _genesisParentVoteMessageHash,
        bytes32 _genesisSourceTransitionHash,
        bytes32 _genesisSourceBlockHash,
        bytes32 _genesisTargetBlockHash,
        uint256 _genesisSourceBlockNumber,
        uint256 _genesisTargetBlockNumber,
        uint256 _genesisProposedMetablockHeight
    )
        public
    {
        assert(_genesisKernelHash != bytes32(0));
        assert(_genesisSourceBlockNumber % _epochLength == 0);
        assert(_genesisTargetBlockHash != bytes32(0));
        assert(_genesisTargetBlockNumber % _epochLength == 0);
        assert(_genesisTargetBlockNumber >= _genesisSourceBlockNumber);
        assert(_genesisProposedMetablockHeight <= _genesisKernelHeight);

        openKernelHeight = _genesisKernelHeight;
        openKernelHash = _genesisKernelHash;

        coconsensus = _coconsensus;

        Protocore.setupProtocore(
            _metachainId,
            _domainSeparator,
            _epochLength,
            _genesisDynasty,
            _genesisProposedMetablockHeight,
            _genesisParentVoteMessageHash,
            _genesisSourceTransitionHash,
            _genesisSourceBlockHash,
            _genesisSourceBlockNumber,
            _genesisTargetBlockHash,
            _genesisTargetBlockNumber
        );
    }


    /* External Functions */

    function getCoconsensus()
		public
		view
		returns (CoconsensusI)
	{
        return coconsensus;
    }

    function proposeLink(
        bytes32 _parentVoteMessageHash,
        bytes32 _sourceTransitionHash,
        bytes32 _targetBlockHash,
        uint256 _targetBlockNumber
    )
        external
    {
        Protocore.proposeLinkInternal(
            _parentVoteMessageHash,
            _sourceTransitionHash,
            _targetBlockHash,
            _targetBlockNumber
        );
    }

    function getParentVoteMessageHash(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (bytes32)
    {
        return links[_voteMessageHash].parentVoteMessageHash;
    }

    function getTargetBlockHash(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (bytes32)
    {
        return links[_voteMessageHash].targetBlockHash;
    }

    function getTargetBlockNumber(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].targetBlockNumber;
    }

    function getSourceTransitionHash(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (bytes32)
    {
        return links[_voteMessageHash].sourceTransitionHash;
    }

    function getProposedMetablockHeight(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].proposedMetablockHeight;
    }

    function getForwardVoteCount(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].forwardVoteCount;
    }

    function getForwardVoteCountNextHeight(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].forwardVoteCountNextHeight;
    }

    function getForwardVoteCountPreviousHeight(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].forwardVoteCountPreviousHeight;
    }

    function getTargetFinalisation(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (CheckpointFinalisationStatus)
    {
        return links[_voteMessageHash].targetFinalisation;
    }
}
