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

import "./CoConsensusI.sol";

contract CoConsensusModule {

    /** Address of CoConsensus contract on auxiliary chain. */
    CoConsensusI public coConsensus;

    /**
     * @notice It sets address for coConsensus contract.
     * @param _coConsensus Address of coConsensus contract.
     */
    function setupCoConsensus(CoConsensusI _coConsensus) public {
        require(
            address(coConsensus) == address(0),
            "CoConsensus address is already present."
        );
        require(
            address(_coConsensus) != address(0),
            "CoConsensus address must not be null."
        );
        coConsensus = _coConsensus;
    }

    modifier onlyCoConsensus()
    {
        require(
            msg.sender == address(coConsensus),
            "Only the CoConsensus contract can call this function."
        );

        _;
    }
}
