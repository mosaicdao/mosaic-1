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

import "../../axiom/Axiom.sol";

contract AxiomTest is Axiom {


    /* Special Member Functions */

    /**
     * Constructor for Axiom contract
     *
     * @param _techGov Technical governance address.
     * @param _consensusMasterCopy Consensus master copy contract address.
     * @param _coreMasterCopy Core master copy contract address.
     * @param _committeeMasterCopy Committee master copy contract address.
     * @param _reputationMasterCopy Reputation master copy contract address.
     * @param _anchorMasterCopy Anchor master copy contract address.
     */
    constructor(
        address _techGov,
        address _consensusMasterCopy,
        address _coreMasterCopy,
        address _committeeMasterCopy,
        address _reputationMasterCopy,
        address _anchorMasterCopy,
        address _consensusGatewayMasterCopy
    )
        public
        Axiom(
            _techGov,
            _consensusMasterCopy,
            _coreMasterCopy,
            _committeeMasterCopy,
            _reputationMasterCopy,
            _anchorMasterCopy,
            _consensusGatewayMasterCopy
        )
    {

    }
    function setConsensus(ConsensusI _consensus) public {
        consensus = _consensus;
    }
}
