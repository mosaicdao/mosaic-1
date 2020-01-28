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

import "../consensus/CoconsensusModule.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title Coreputation contract.
 *
 * @notice Coreputation contract stores validator status and reputation value
 *         for validators.
 */
contract Coreputation is MasterCopyNonUpgradable, CoconsensusModule {

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
     * @notice Insert or update validator information.
     *
     * @dev Validator information is not updated when his status is Slashed.
     *      Validator is marked Deregistered if provided reputation is zero.
     *      Validator is marked Staked, if he has non zero reputation value.
     *
     * @dev Function requires:
     *      - msg.sender should be Coconsensus
     *
     * @param _validator Validator address to upsert.
     * @param _reputation Validator reputation value.
     */
    function upsertValidator(
        address _validator,
        uint256 _reputation
    )
        external
        onlyCoconsensus
    {
        ValidatorInfo storage vInfo = validators[_validator];
        if (vInfo.status != ValidatorStatus.Slashed) {
            vInfo.reputation = _reputation;
            if (_reputation == uint256(0)) {
                vInfo.status = ValidatorStatus.Deregistered;
            } else {
                assert(vInfo.status <= ValidatorStatus.Staked);
                vInfo.status = ValidatorStatus.Staked;
            }
        }
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
