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

/**
 * @title ValidatorSet contract.
 *
 * @notice It contains methods to maintain validators for a metablock.
 */
contract ValidatorSet {

    /* Constants */

    /** Maximum future end height, set for all active validators. */
    uint256 public constant MAX_FUTURE_END_HEIGHT = uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    /** Sentinel pointer for marking start and end of linked-list of validators. */
    address public constant SENTINEL_VALIDATORS = address(0x1);


    /* Storage */

    /** Linked list of validators. */
    mapping(address => address) validators;

    /**
     * Validator begin height assigned to this set:
     *   - zero: not registered to this set, or started at height 0
     *           if endHeight > 0.
     *   - bigger than zero: begin height for active validators.
     */
    mapping(address => uint256) public validatorBeginHeight;

    /**
     * Validator end height assigned to this set:
     *   - zero: not registered to this set.
     *   - MAX_FUTURE_END_HEIGHT: for active validators.
     *   - less than MAX_FUTURE_END_HEIGHT: for logged out validators.
     */
    mapping(address => uint256) public validatorEndHeight;


    /* Public Functions */

    /**
     * @notice Checks if validator is in validator set or not.
     *
     * @param _validator Address of validator.
     * @param _height Metablock height.
     * Returns true if validator with given metablock height is in validator
     * set.
     */
    function inValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool)
    {
        return validatorBeginHeight[_validator] <= _height &&
            validatorEndHeight[_validator] >= _height &&
            validatorEndHeight[_validator] > 0;
    }

    /**
     * @notice Checks if validator is in forward validator set or not.
     *
     * @param _validator Address of validator.
     * @param _height Metablock height.
     * Returns true if validator with given metablock height is in forward
     * validator set.
     */
    function inForwardValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool)
    {
        return validatorBeginHeight[_validator] <= _height &&
            validatorEndHeight[_validator] > _height &&
            validatorEndHeight[_validator] > 0;
    }
}
