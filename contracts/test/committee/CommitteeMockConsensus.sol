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

import "../../committee/Committee.sol";
import "../../consensus/ConsensusI.sol";

contract CommitteeMockConsensus is ConsensusI {

    /* Storage */

    /** Precommits under consideration of committees. */
    mapping(address /* committee */ => bytes32 /* commit */) public decisions;


    /* External Functions */

    function registerCommitteeDecision(
        bytes32 /* _metachainId */,
        bytes32 _committeeDecision
    )
        external
    {
        require(
            decisions[msg.sender] == bytes32(0),
            "Committee's decision has been registered."
        );

        decisions[msg.sender] = _committeeDecision;
    }

    function reputation()
        external
        view
        returns (ReputationI)
    {
    }

    function coreValidatorThresholds()
        external
        view
        returns (uint256, uint256)
    {
    }

    function precommitMetablock(
        bytes32 /* _metachainId */,
        bytes32 /* _proposal */
    )
        external
    {
    }

    function newMetaChain(
        address /* _anchor */,
        uint256 /* _epochLength */,
        uint256 /* _rootBlockHeight */
    )
        external
    {
    }

    function enterCommittee(
        address _committee,
        address _validator,
        address _furtherMember
    )
        external
    {
        Committee(_committee).enterCommittee(
            _validator,
            _furtherMember
        );
    }
}
