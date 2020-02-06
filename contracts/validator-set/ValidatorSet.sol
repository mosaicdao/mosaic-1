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

import "./ForwardValidatorSetAbstract.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title ValidatorSet contract.
 *
 * @notice It contains methods to maintain validators for a metablock.
 */
contract ValidatorSet is ForwardValidatorSetAbstract {

    /* Usings */

    using SafeMath for uint256;


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

    /**
     * Validator set count per height.
     * Recursively the validator count, N, for height, h, can be written as:
     *     N_h = N_(h-1) + J_h - L_(h-1)
     * where J_h is the number of validators joining at height h, and
     * L_(h-1) is the number of validators that logged out at h-1 (equals their end-height).
     */
    mapping(uint256 /* metablock height */ => uint256 /* validator count */) private validatorCount;

    /**
     * Forward validator set (FVS) count per height.
     * The number of validators in the FVS at a given height, F_h, equals
     * the number of validators at that height, N_h, minus the validators that have logged out at h:
     *     F_h = N_h - L_h
     */
    mapping(uint256 /* metablock height */ => uint256 /* FVS count */) private fvsCount;

    /**
     * Active height constrains the insertion and removal of validators
     * to the active height. Any insertion or removal can increment
     * the active height with one.
     * Active height is private to ValidatorSet and intended to run ahead of
     * the (open) metablock height from Core or Protocore with only a loose coupling.
     * Active height is introduced to the calculation of the forward validator set count
     * to a sliding-window calculation.
     */
    uint256 private activeHeight;


    /* Modifiers */

    modifier onlyActiveHeight(uint256 _height)
    {
        require(
            activeHeight == _height,
            "Height must equal active height."
        );
        _;
    }


    /* Special Functions */

    /**
     * @notice setupValidatorSet initializes validator set linked-list.
     */
    function setupValidatorSet(uint256 _activeHeight)
        internal
    {
        activeHeight = _activeHeight;
        validators[SENTINEL_VALIDATORS] = SENTINEL_VALIDATORS;
    }


    /* Public Functions */

    /**
     * @notice Checks if validator is in validator set or not.
     *
     * @param _validator Address of validator.
     * @param _height Metablock height.
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

    /**
     * @notice returns the validator set count for heights up to active height, but not included.
     *
     * @dev Function requires:
     *          - height is less than active height
     *
     * @param _height Height for which to return the validator set count.
     */
    function validatorSetCount(uint256 _height)
        public
        view
        returns (uint256)
    {
        require(
            _height < activeHeight,
            "Validator set count is only defined up to active height."
        );
        return validatorCount[_height];
    }

    /**
     * @notice returns the forward validator set count for heights up to active height, but not included.
     *
     * @dev Function requires:
     *          - height is less than active height
     *
     * @param _height Height for which to return the forward validator set count.
     */
    function forwardValidatorSetCount(uint256 _height)
        public
        view
        returns (uint256)
    {
        require(
            _height < activeHeight,
            "Forward validator set count is only defined up to active height."
        );
        return fvsCount[_height];
    }

    /* Internal Functions  */

    /**
     * @notice Increments the active height, and height must be explicitly provided.
     *         IncrementActiveHeight must be called on opening a new height, and
     *         _nextHeight is the new `openKernelHeight + 1`.
     *
     * @param _nextHeight Incremented height equaling active height plus one.
     */
    function incrementActiveHeightInternal(uint256 _nextHeight)
        internal
    {
        assert(_nextHeight == activeHeight.add(1));

        // before increasing active height, h -> h+1,
        // initialize N_(h+2) = N_(h+1)
        // and F_(h+1) = N_(h+1), for calculating the running counts.
        validatorCount[_nextHeight.add(1)] = validatorCount[_nextHeight];
        fvsCount[_nextHeight] = validatorCount[_nextHeight];

        activeHeight = _nextHeight;
    }

    /**
     * @notice Inserts validators into the validator set and sets begin height.
     *
     * @dev Function asserts :
     *          - Validator address must not be 0.
     *          - Validator address is not already present.
     *          - Validator begin height must be equal to active height or active height plus one.
     *
     * @param _validator Validator address.
     * @param _beginHeight Begin height for the validator.
     */
    function insertValidatorInternal(
        address _validator,
        uint256 _beginHeight
    )
        internal
        onlyActiveHeight(_beginHeight)
    {
        assert(_validator != address(0));
        assert(validators[_validator] == address(0));

        address lastValidator = validators[SENTINEL_VALIDATORS];
        assert(lastValidator != address(0));
        validators[_validator] = lastValidator;
        validators[SENTINEL_VALIDATORS] = _validator;

        validatorBeginHeight[_validator] = _beginHeight;
        validatorEndHeight[_validator] = MAX_FUTURE_END_HEIGHT;

        // on inserting a validator at height h
        //     N_h ++
        //     N_(h+1) ++
        //     F_h ++
        uint256 updatedValidatorCount = validatorCount[activeHeight].add(1);
        validatorCount[activeHeight] = updatedValidatorCount;
        validatorCount[activeHeight.add(1)] = updatedValidatorCount;
        fvsCount[activeHeight] = fvsCount[activeHeight].add(1);
    }

    /**
     * @notice Removes validators from the validator set and sets end height.
     *
     * @dev Function requires :
     *          - Validator end height must be greater than begin height.
     *          - Validator end height must be equal to MAX_FUTURE_END_HEIGHT.
     *          - Validator end height must be equal to active height or active height plus one.
     *
     * @param _validator Validator address.
     * @param _endHeight End height for the validator.
     */
    function removeValidatorInternal(
        address _validator,
        uint256 _endHeight
    )
        internal
        onlyActiveHeight(_endHeight)
    {
        require(
            validatorBeginHeight[_validator] < _endHeight,
            "End height must be strictly greater than the start height."
        );

        assert(
            validatorEndHeight[_validator] == MAX_FUTURE_END_HEIGHT
        );

        validatorEndHeight[_validator] = _endHeight;

        // on removing a validator at height h
        //     N_(h+1) --
        //     F_h --
        uint256 nextHeight = activeHeight.add(1);
        validatorCount[nextHeight] = validatorCount[nextHeight].sub(1);
        fvsCount[activeHeight] = fvsCount[activeHeight].sub(1);
    }
}
