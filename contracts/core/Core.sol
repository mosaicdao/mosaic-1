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

import "../consensus/ConsensusModule.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Core is ConsensusModule {

    using SafeMath for uint256;

    /* Enum and structs */

    /* Storage */

    /** Validators assigned to this core */
    mapping(address => address) public validators;

    /** Reputation contract */
    ReputationI public reputation;

    /* External and public functions */

    constructor()
        ConsensusModule(msg.sender)
        public
    {

    }


    function join(address _validator)
        external
        onlyConsensus
    {

    }

    /* Internal and private functions */

    /**
     * insert validator in linked-list
     */
    function insertValidator(address _validator)
        internal
    {
        require(_validator != address(0),
            "Validator must not be null address.");
        require(_validator != SENTINEL_VALIDATORS,
            "Validator must not be Sentinel address.");
        require(validators[_validator] == address(0),
            "Validator must not already be part of this core.");

        validators[_validator] = validators[SENTINEL_VALIDATORS];
        validators[SENTINEL_VALIDATORS] = _validator;
    }

    /**
     * remove validator from linked-list
     */
    function removeValidator(address _validator, address _prevValidator)
        internal
    {
        require(_validator != address(0) &&
            _validator != SENTINEL_VALIDATORS,
            "Validator null or sentinel address cannot be removed.");
        require(_validator == validators[_prevValidator],
            "Invalid validator-pair provided to remove validator from core.");
        validators[_prevValidator] = validators[_validator];
        delete validators[_validator];
    }
}