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

import "../consensus/CoConsensusModule.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

contract Coreputation is MasterCopyNonUpgradable, CoConsensusModule {

    /** Validator status enum */
    enum ValidatorStatus {

        /** Undefined as null value */
        Undefined,

        /** Validator has been slashed and lost stake and earnings */
        Slashed,

        /** Validator has put up stake and participates in consensus */
        Staked,

        /** Validator has deregistered and no longer participates in consensus */
        Deregistered
    }


    /* Structs */

    struct ValidatorInfo {
        ValidatorStatus status;
        uint256 reputation;
    }


    /* Storage */

    /** Validators info */
    mapping(address => ValidatorInfo) public validators;


    /* External functions */

    /**
     * @notice It sets up coreputation contract. It can only be called once.
     *
     * @dev TODO Remove setup method after coConsensus storage variable is made
     *      constant value in CoConsensusModule.
     *
     * @param _coConsensus Address of coConsensus contract.
     */
    function setup(
        CoConsensusI _coConsensus
    )
        external
    {
        CoConsensusModule.setupCoConsensus(_coConsensus);
    }
}
