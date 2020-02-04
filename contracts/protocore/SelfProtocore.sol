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

import "../protocore/Protocore.sol";
import "../protocore/GenesisSelfProtocore.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../validator/ValidatorSet.sol";

/**
 * @title Self protocore - This contract finalizes the proposed blocks of auxiliary chain.
 */
contract SelfProtocore is MasterCopyNonUpgradable, GenesisSelfProtocore, ValidatorSet, Protocore {

    /* Special Functions */

    /**
     * @notice setup() function initializes the current contract.
     *
     * @dev These input params will be provided by the coconsensus contract.
     *      This can be called only by the coconsensus contract once.
     *
     * \post Sets `domainSeparator` to the given value.
     * \post Sets `epochLength` to the given value.
     * \post Sets `metachainId` to the given value.
     * \post Sets genesis link.
     */
    function setup() external onlyCoconsensus {
        Protocore.setupProtocore(
            genesisAuxiliaryMetachainId,
            genesisDomainSeparator,
            genesisEpochLength,
            genesisDynasty,
            genesisMetablockHeight,
            genesisAuxiliaryParentVoteMessageHash,
            genesisAuxiliarySourceTransitionHash,
            genesisAuxiliarySourceBlockHash,
            genesisAuxiliarySourceBlockNumber,
            genesisAuxiliaryTargetBlockHash,
            genesisAuxiliaryTargetBlockNumber
        );
        ValidatorSet.setupValidatorSet();
    }


    /* External Functions */

    /**
     * @notice Insert or remove validator. It inserts validator if not already
     *         present and reputation is greater than 0. It removes validator
     *         if it is present and reputation is 0.
     *
     * @dev Function requires:
     *      - Caller should be Coconsensus contract.
     *      - Validator can get joined/removed only at height one greater than
     *        current open kernel height.
     *
     * @param _validator Validator address to upsert.
     * @param _height Validator start or end height to be updated.
     * @param _reputation Validator's reputation value.
     */
    function upsertValidator(
        address _validator,
        uint256 _height,
        uint256 _reputation
    )
        external
        onlyCoconsensus
    {
        assert(_height == openKernelHeight.add(1));
        if(ValidatorSet.inValidatorSet(_validator, openKernelHeight)) {
            if(_reputation == 0) {
                removeValidatorInternal(_validator, _height);
            }
        }
        else {
            if(_reputation > 0) {
                insertValidatorInternal(_validator, _height);
            }
        }
    }
}
