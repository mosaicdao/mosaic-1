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

import "../../consensus/Consensus.sol";

contract ConsensusTest is Consensus {

    constructor(uint256 _committeeSize)
        public
        Consensus(_committeeSize)
    {

    }

    function setCoreStatus(
        address _core,
        bytes20 _status
    )
        external
    {
        coreStatuses[_core] = _status;
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
}
