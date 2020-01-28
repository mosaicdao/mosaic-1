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
    mapping(address => address) public validators;

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


    /* Special Functions */

    /**
     * @notice It initializes validators set.
     */
    function setupValidatorSet()
        internal
    {
        validators[SENTINEL_VALIDATORS] = SENTINEL_VALIDATORS;
    }


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


    /* Internal Functions  */

    /**
     * @notice It is for inserting validators into the validator set.
     *
     * @dev Function requires :
     *          - Validator address must not be 0.
     *          - Validator address is already not used.
     *
     * @param _validator Validator address.
     * @param _beginHeight Begin height for the validator.
     */
    function insertValidatorInternal(
        address _validator,
        uint256 _beginHeight
    )
        internal
    {
        assert(_validator != address(0));
        assert(
            validatorBeginHeight[_validator] == 0 && validatorEndHeight[_validator] == 0
        );

        address lastValidator = validators[SENTINEL_VALIDATORS];
        validators[_validator] = lastValidator;
        validators[SENTINEL_VALIDATORS] = _validator;

        validatorBeginHeight[_validator] = _beginHeight;
        validatorEndHeight[_validator] = MAX_FUTURE_END_HEIGHT;
    }

    /**
     * @notice It is for removing validators from the validator set.
     *
     * @dev Function requires :
     *          - Validator address must not be 0.
     *          - Validator begin height must be less than end height.
     *          - Validator end height must be equal to MAX_FUTURE_END_HEIGHT.
     *
     * @param _validator Validator address.
     * @param _endHeight End height for the validator.
     */
    function removeValidatorInternal(
        address _validator,
        uint256 _endHeight
    )
        internal
    {
        assert(
            validatorBeginHeight[_validator] < _endHeight
        );
        assert(
            validatorEndHeight[_validator] == MAX_FUTURE_END_HEIGHT
        );

        validatorEndHeight[_validator] = _endHeight;
    }
}
