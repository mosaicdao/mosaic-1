pragma solidity ^0.5.0;

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

import "../../consensus/ConsensusI.sol";
import "../../reputation/ReputationI.sol";
import "../core/MockCore.sol";

contract MockConsensus is ConsensusI, ReputationI {

    /* Storage */

    uint256 minValidatorCount;

    uint256 validatorJoinLimit;

    MockCore public mockCore;

    mapping(address => uint256) public rep;

    mapping(address => bytes32) public precommitts;


    /* Special Functions */

    constructor(
        bytes32 _metachainId,
        uint256 _epochLength,
        uint256 _minValidatorCount,
        uint256 _validatorJoinLimit,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        uint256 _sourceBlockHeight
    )
        public
    {
        minValidatorCount = _minValidatorCount;
        validatorJoinLimit = _validatorJoinLimit;

        mockCore = new MockCore();
        mockCore.setup(
			ConsensusI(address(this)),
            _metachainId,
            _epochLength,
            minValidatorCount,
            validatorJoinLimit,
            ReputationI(this),
            _height,
            _parent,
            _gasTarget,
            _dynasty,
            _accumulatedGas,
            _sourceBlockHeight
        );
    }


    /* External Functions */

    function joinDuringCreation(address _validator)
        external
    {
        rep[_validator] = uint256(1);
        mockCore.joinBeforeOpen(_validator);
    }

    function join(address _validator)
        external
    {
        rep[_validator] = uint256(1);
        mockCore.join(_validator);
    }

    function logout(address _validator)
        external
    {
        rep[_validator] = uint256(0);
        mockCore.logout(_validator);
    }

    function stake(address _validator, address _withdrawalAddress)
        external
    {
        // do nothing for now
    }

    function deregister(address _validator)
        external
    {
        // do nothing for now
    }

    function removeVote(address _validator)
        external
    {
        mockCore.removeVote(_validator);
    }

    function isSlashed(address _validator)
        public
        view
        returns (bool)
    {
        return (rep[_validator] == 0);
    }

    function getReputation(address _validator)
        external
        view
        returns (uint256)
    {
        return rep[_validator];
    }

    function setReputation(address _validator, uint256 _newReputation)
        external
    {
        rep[_validator] = _newReputation;
    }

    function reputation()
        external
        view
        returns (ReputationI)
    {
        return this;
    }

    function coreValidatorThresholds()
        external
        view
        returns (uint256 minimumValidatorCount_, uint256 joinLimit_)
    {
        minimumValidatorCount_ = minValidatorCount;
        joinLimit_ = validatorJoinLimit;
    }

    function precommitMetablock(
        bytes32 /* _metachainId */,
        bytes32 _precommit
    )
        external
    {
        precommitts[msg.sender] = _precommit;
    }

    function registerCommitteeDecision(bytes32, bytes32)
        external
    {
        // do nothing for now
    }

    function newMetaChain()
        external
        returns(bytes32 metachainId_)
    {
        // do nothing for now
    }

    function join(
        address _validator,
        address _withdrawalAddress
    )
        external
    {
        // do nothing for now
    }

    function openMetablock(
        uint256 _committedDynasty,
        uint256 _committedAccumulatedGas,
        uint256 _committedSourceBlockHeight,
        uint256 _deltaGasTarget
    )
        external
    {
        mockCore.openMetablock(
            _committedDynasty,
            _committedAccumulatedGas,
            _committedSourceBlockHeight,
            _deltaGasTarget
        );
    }

    function isPrecommitted(address _core)
        external
        view
        returns (bool)
    {
        return precommitts[_core] != bytes32(0);
    }
}
