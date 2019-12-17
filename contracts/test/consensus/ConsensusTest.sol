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

import "../../consensus/Consensus.sol";

contract ConsensusTest is Consensus {

    constructor()
        public
        Consensus()
    {

    }

    function setCoreLifetime(
        address _core,
        CoreLifetime _status
    )
        external
    {
        coreLifetimes[_core] = _status;
    }

    function setPreCommit(
        address _core,
        bytes32 _proposal,
        uint256 _committeeFormationBlockheight
    )
        external
    {
        precommits[_core] = Precommit(
            _proposal,
            _committeeFormationBlockheight
        );
    }

    function setCommittee(
        address _committeeAddress,
        address _value
    )
        external
    {
        committees[_committeeAddress] = _value;
    }

    function setReputation(address _reputation) external {
        reputation = ReputationI(_reputation);
    }

    function setAssignment(
        bytes32 _metachainId,
        address _core
    )
        external
    {
        assignments[_metachainId] = _core;
    }

    function setCommitteeProposal(
        address _committeeAddress,
        bytes32 _proposal
    )
        external
    {
        proposals[_proposal] = CommitteeI(_committeeAddress);
    }

    function setAnchor(
        bytes32 _metachainId,
        address _anchor
    )
        external
    {
        anchors[_metachainId] = _anchor;
    }

    function setConsensusGateway(
        bytes32 _metachainId,
        address _consensusGateway
    )
        external
    {
        consensusGateways[_metachainId] = ConsensusGatewayI(_consensusGateway);
    }
}
