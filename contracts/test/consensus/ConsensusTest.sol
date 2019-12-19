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

    function setPrecommit(
        bytes32 _metachainId,
        bytes32 _precommit
    )
        external
    {
        uint256 metablockTip = metablockTips[_metachainId];
        Metablock storage metablock = metablockchains[_metachainId][metablockTip];

        metablock.metablockHash = _precommit;
        metablock.round = MetablockRound.Precommitted;
        metablock.roundBlockNumber = block.number;
    }

    function setCommittee(
        bytes32 _metachainId,
        address _committeeAddress
    )
        external
    {
        committees[_metachainId] = CommitteeI(_committeeAddress);
    }

    function setReputation(address _reputation) external {
        reputation = ReputationI(_reputation);
    }

    function setAssignment(
        bytes32 _metachainId,
        CoreI _core
    )
        external
    {
        assignments[_metachainId] = _core;
    }

    function setCommitteeProposal(
        CommitteeI _committeeAddress,
        bytes32 _proposal
    )
        external
    {
        committees[_proposal] = _committeeAddress;
    }

    function setAnchor(
        bytes32 _metachainId,
        AnchorI _anchor
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
