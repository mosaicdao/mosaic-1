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
import "../../validator-set/ValidatorSet.sol";

contract TestProtocore is Protocore {

	/* Storage */

    CoconsensusI public coconsensus;

    mapping(uint256 /* metablock height */ => mapping(address /* validator */ => bool)) fvs;
    mapping(uint256 /* metablock height */ => uint256 /* fvs count */) fvsCounts;


    /* Functions */

    constructor(
        CoconsensusI _coconsensus,
        bytes32 _metachainId,
        bytes32 _domainSeparator,
        uint256 _epochLength,
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
            _genesisProposedMetablockHeight,
            _genesisParentVoteMessageHash,
            _genesisSourceTransitionHash,
            _genesisSourceBlockHash,
            _genesisSourceBlockNumber,
            _genesisTargetBlockHash,
            _genesisTargetBlockNumber
        );
    }

    function getCoconsensus()
        public
        view
        returns (CoconsensusI)
    {
        return coconsensus;
    }

    function openKernel(
        uint256 _kernelHeight,
        bytes32 _kernelHash
    )
        external
    {
        Protocore.openKernelInternal(_kernelHeight, _kernelHash);
    }

    function addToFVS(address _validator, uint256 _height)
        external
    {
        assert(_validator != address(0));
        assert(fvs[_height][_validator] == false);

        fvs[_height][_validator] = true;
        fvsCounts[_height] = fvsCounts[_height].add(1);
    }

    function inValidatorSet(address, uint256)
        public
        view
        returns (bool)
    {
        // @todo (pro): Implement it.
        return true;
    }

    function inForwardValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool)
    {
        return fvs[_height][_validator];
    }

    function forwardValidatorSetCount(uint256 _height)
        public
        view
        returns (uint256)
    {
        return fvsCounts[_height];
    }

    function registerVote(
        bytes32 _voteMessageHash,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        external
    {
        Protocore.registerVoteInternal(
            _voteMessageHash,
            _r,
            _s,
            _v
        );
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
        bytes32 _voteMessageHash,
        uint256 _height
    )
        external
        view
        returns (uint256)
    {
        return links[_voteMessageHash].fvsVoteCount[_height];
    }

    function hasVoted(
        bytes32 _voteMessageHash,
        uint256 _height,
        address _validator
    )
        external
        view
        returns (bool)
    {
        return fvsVotes[_voteMessageHash][_height][_validator] != address(0);
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

    function getSourceFinalisation(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (CheckpointFinalisationStatus)
    {
        Link storage link = links[_voteMessageHash];
        Link storage parentLink = links[link.parentVoteMessageHash];

        return parentLink.targetFinalisation;
    }

    function isFinalisationLink(
        bytes32 _voteMessageHash
    )
        external
        view
        returns (bool)
    {
        Link storage link = links[_voteMessageHash];

        Link storage parentLink = links[link.parentVoteMessageHash];

        return link.targetBlockNumber.sub(parentLink.targetBlockNumber) == epochLength;
    }

    function getVoteCount(
        bytes32 _voteMessageHash,
        uint256 _height
    )
        external
        view
        returns (uint256)
    {
        Link storage link = links[_voteMessageHash];
        return link.fvsVoteCount[_height];
    }
}
