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

import "./CoConsensusI.sol";

contract CoConsensusModule {

    /* Constants */

    /** Address of CoConsensus contract on auxiliary chain. */
    CoConsensusI private constant coConsensusAddress = CoConsensusI(address(0x0000000000000000000000000000000000004D00));


    /* Modifiers */

    modifier onlyCoConsensus()
    {
        require(
            msg.sender == address(coConsensus()),
            "Only the CoConsensus contract can call this function."
        );

        _;
    }


    /* Public functions */

    /**
     * @notice Gets the coconsensus contract address.
     *
     * @return Coconsensus contract address.
     */
    function coConsensus() public pure returns (CoConsensusI) {
        return coConsensusAddress;
    }
}
