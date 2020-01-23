pragma solidity >=0.5.0 <0.6.0;

// Copyright 2020 OpenST Ltd.
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

/**
 * @title Coreputation contract.
 *
 * @notice Coreputation contract stores validator status and reputation value
 *         for validators.
 */
contract Coreputation is MasterCopyNonUpgradable, CoConsensusModule {

    /** Validator status enum */
    enum ValidatorStatus {

        /** Undefined as null value */
        Undefined,

        /** Validator has been slashed and lost stake and earnings */
        Slashed,

        /** Validator has put up stake and participates in consensus */
        Staked,

        /** Validator has been deregistered and no longer participates in consensus */
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
     * @notice It sets up Coreputation contract. It can only be called once.
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

    /**
     * @notice Insert or update validator information.
     *
     * @dev Validator status is marked Staked, if validator status is
     *      Undefined and he has non zero reputation value.
     *      Validator status is marked to Deregistered when his current status
     *      is Staked and reputation value changes to zero.
     *
     * @dev Function requires:
     *      - msg.sender should be CoConsensus
     *      - Validator address should non zero
     *      - Newly added validators reputation should be non zero
     *
     * @param _validator Validator address to upsert.
     * @param _reputation Validator reputation value.
     */
    function upsertValidator(
        address _validator,
        uint256 _reputation
    )
        external
        onlyCoConsensus
    {
        ValidatorInfo storage vInfo = validators[_validator];
        if (vInfo.status == ValidatorStatus.Undefined) {

            require(
                _reputation > uint256(0),
                "Validator reputation is 0."
            );

            vInfo.status = ValidatorStatus.Staked;
        } else {
            if(_reputation == uint256(0) &&
                vInfo.status == ValidatorStatus.Staked) {
                vInfo.status = ValidatorStatus.Deregistered;
            }
        }

        vInfo.reputation = _reputation;
    }

    /**
     * @notice Returns reputation of a validator.
     *
     * @param _validator An address of a validator.
     * Returns validator reputation.
     */
    function getReputation(address _validator)
        external
        view
        returns (uint256)
    {
        return validators[_validator].reputation;
    }


    /* Public Functions */

    /**
     * @notice Check if the validator address is slashed or not.
     *
     * @param _validator An address of a validator.
     * Returns true if the specified address is slashed.
     */
    function isSlashed(address _validator)
        public
        view
        returns(bool)
    {
        return validators[_validator].status == ValidatorStatus.Slashed;
    }
}
