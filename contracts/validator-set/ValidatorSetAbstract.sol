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

/**
 * @title ValidatorSetAbstract abstract contract specifies a validator
 *        set abstract interfaces.
 */
contract ValidatorSetAbstract {

    /* Public Functions */

    /**
     * @notice inValidatorSet() function checks if a validator is in
     *         validator set for the given height.
     *
     * @param _validator A validator's address to check.
     * @param _height A metablock height.
     *
     * @return Returns true if a validator is in the validator set
     *         for the given metablock height, otherwise false.
     */
    function inValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool);

    /**
     * @notice inForwardValidatorSet() function checks if a validator is in
     *         forward validator set for the given height.
     *
     * @param _validator A validator's address to check.
     * @param _height A metablock height.
     *
     * @return Returns true if a validator is in the forward validator set
     *         for the given metablock height, otherwise false.
     */
    function inForwardValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool);

    /**
     * @notice forwardValidatorSetCount() function returns a count of validators
     *         included in a forward validator set for the given metablock
     *         height.
     *
     * @param _height A metablock height.
     *
     * \pre _height must be less than the active height.
     *
     * @return Returns a count of forward validators for the given metablock
     *         height.
     */
    function forwardValidatorSetCount(uint256 _height)
        public
        view
        returns (uint256);
}
