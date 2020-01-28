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

import "../../validator/ValidatorSet.sol";

/**
 * @title ValidatorSetDouble contract.
 *
 * @notice It is used for testing ValidatorSet contract.
 */
contract ValidatorSetDouble is ValidatorSet {

    /* External Functions */

    function setupValidator()
        external
    {
        ValidatorSet.setup();
    }

    /**
     * @notice It is used to insert validator.
     *
     * @param _validator Validator address.
     * @param _beginHeight Begin height for the validator.
     */
    function insertValidator(address _validator, uint256 _beginHeight) external {
        insertValidatorInternal(_validator, _beginHeight);
    }

   /**
    * @notice It is used to remove validator.
    *
    * @param _validator Validator address.
    * @param _endHeight End height for the validator.
    */
    function removeValidator(address _validator, uint256 _endHeight) external {
        removeValidatorInternal(_validator, _endHeight);
    }
}
