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

import "../EIP20I.sol";
import "../consensus/ConsensusModule.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Reputation is ConsensusModule {

    using SafeMath for uint256;

    /* Enum and structs */

    /** Validator status enum */
    enum ValidatorStatus {
        /** Undefined as null value */
        Undefined,

        /** Validator has been slashed and lost stake and rewards */
        Slashed,

        /** Validator has put up stake and participates in consensus */
        Staked,

        /** Validator has logged out and no longer participates in consensus */
        LoggedOut,

        /** Validator has withdrawn stake after logging out and cooldown period */
        Withdrawn
    }

    /* Storage */

    /** Sentinel pointer for marking end of linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);

    /** Address of previous validator in linked list */
    mapping(address => address) public validators;

    /** Status */
    mapping(address => ValidatorStatus) public status;

    /** Withdrawal address */
    mapping(address => address) public withdrawalAddress;

    /** Earned rewards */
    mapping(address => uint256) public reward;

    /** Reputation earned */
    mapping(address => uint256) public reputation;

    /** Value token */
    EIP20I public valueToken;

    /** External / public functions */

    constructor(address _consensus)
        ConsensusModule(_consensus)
        public
    {
        // valueToken = consensus.valueToken();
    }

    function join(address _validator)
        onlyConsensus
        external
        view
    {
        require(status[_validator] == ValidatorStatus.Undefined,
            "No validator can rejoin.");
        // continue
    }

    function logout(address _validator)
        onlyConsensus
        external
        view
    {
        // continue
    }
}