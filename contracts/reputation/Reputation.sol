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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../EIP20I.sol";
import "../consensus/ConsensusModule.sol";

contract Reputation is ConsensusModule {

    /* Usings */
    using SafeMath for uint256;


    /* Constants */

    /** Sentinel pointer for marking end of linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);


    /* Enums */

    /** Validator status enum */
    enum ValidatorStatus {
        /** Undefined as null value */
        Undefined,

        /** Validator has put up stake and participates in consensus */
        Staked,

        /** Validator has been slashed and lost stake and rewards */
        Slashed,

        /** Validator has logged out and no longer participates in consensus */
        LoggedOut,

        /** Validator has withdrawn stake after logging out and cooldown period */
        Withdrawn
    }


    /* Storage */

    /** EIP20 mOST for stakes and rewards for validators. */
    EIP20I public mOST;

    /** EIP20 wETH for stakes and rewards for validators. */
    EIP20I public wETH;

    /** Required stake amount in mOST to join as a validator */
    uint256 public stakeMOSTAmount;

    /** Required stake amount in wETH to join as a validator */
    uint256 public stakeWETHAmount;

    /** Initial reputation for the newly joined validator. */
    uint256 public initialReputation;

    /** Address of previous validator in linked list */
    mapping(address => address) public validators;

    /** Status */
    mapping(address => ValidatorStatus) public statuses;

    /** Withdrawal address */
    mapping(address => address) public withdrawalAddresses;

    /** Reputation earned */
    mapping(address => uint256) public reputations;


    /* Modifiers */

    modifier isActive(address _validator)
    {
        require(
            statuses[_validator] == ValidatorStatus.Staked,
            "Validator is not active."
        );

        _;
    }

    modifier hasJoined(address _validator)
    {
        require(
            statuses[_validator] != ValidatorStatus.Undefined,
            "Validator was not joined."
        );

        _;
    }


    /* Special Member Functions */

    /**
     * @dev Function requires:
     *          - mOST token address is not 0
     *          - wETH token address is not 0
     *          - a stake amount to join in mOST is positive
     *          - a stake amount to join in wETH is positive
     *          - an initial reputation for newly joined validators is positive
     */
    constructor(
        address _consensus,
        EIP20I _mOST,
        uint256 _stakeMOSTAmount,
        EIP20I _wETH,
        uint256 _stakeWETHAmount,
        uint256 _initialReputation
    )
        ConsensusModule(_consensus)
        public
    {
        require(
            _mOST != EIP20I(0),
            "mOST token address is 0."
        );

        require(
            _wETH != EIP20I(0),
            "wETH token address is 0."
        );

        require(
            _stakeMOSTAmount > 0,
            "Stake amount to join in mOST is not positive."
        );

        require(
            _stakeWETHAmount > 0,
            "Stake amount to join in wETH is not positive."
        );

        require(
            _initialReputation > 0,
            "Initial reputation for newly joined valiator is not positive."
        );

        mOST = _mOST;
        wETH = _wETH;
        stakeMOSTAmount = _stakeMOSTAmount;
        stakeWETHAmount = _stakeWETHAmount;
        initialReputation = _initialReputation;

        // Initialize the validators linked-list as the empty set.
        validators[SENTINEL_VALIDATORS] = SENTINEL_VALIDATORS;
    }


    /* External Functions */

    /**
     * @notice Increases reputation of a validator by delta.
     *
     * @dev Function requires
     *          - only consensus can call
     *          - the specified validator is active
     *
     * @param _validator A validator for which to increase a reputation.
     * @param _delta A change (delta) to increase a validator's reputation.
     *
     * @return Returns an updated reputation.
     */
    function increase(address _validator, uint256 _delta)
        external
        onlyConsensus
        isActive(_validator)
        returns (uint256)
    {
        reputations[_validator] = reputations[_validator].add(_delta);

        return reputations[_validator];
    }

    /**
     * @notice Decreases reputation of a validator by delta.
     *         Sets the validator's reputation to 0 if after operation
     *         it's negative.
     *
     * @dev Function requires:
     *          - only consensus can call.
     *          - the specified validator is active.
     *
     * @param _validator A validator for which to decrease a reputation.
     * @param _delta A change (delta) to decrease a validator's reputation.
     *
     * @return Returns an updated reputation.
     */
    function decrease(address _validator, uint256 _delta)
        external
        onlyConsensus
        isActive(_validator)
        returns (uint256)
    {
        if (reputations[_validator] < _delta) {
            reputations[_validator] = 0;
        } else {
            reputations[_validator] = reputations[_validator].sub(_delta);
        }

        return reputations[_validator];
    }

    /**
     * @dev Function requires:
     *          - only consensus can call
     *          - a validator was not joined previously
     *          - a validator address is not 0
     *          - a withdrawal address is not 0
     *          - a validator address is not same as its withdrawal address
     *          - a validator approved in mOST token contract to transfer
     *            a stake amount.
     *          - a validator approved in wETH token contract to transfer
     *            a stake amount.
     */
    function join(
        address _validator,
        address _withdrawalAddress
    )
        external
        onlyConsensus
    {
        require(
            _validator != address(0),
            "Validator address is 0."
        );

        require(
            _withdrawalAddress != address(0),
            "Validator's withdrawal address is 0."
        );

        require(
            _validator != _withdrawalAddress,
            "Validator's address is the same as its withdrawal address."
        );

        require(
            statuses[_validator] == ValidatorStatus.Undefined,
            "No validator can rejoin."
        );

        require(
            validators[_validator] == address(0),
            "No validator can rejoin."
        );

        // adding a validator into the circular link-list of validators.
        validators[_validator] = validators[SENTINEL_VALIDATORS];
        validators[SENTINEL_VALIDATORS] = _validator;

        statuses[_validator] = ValidatorStatus.Staked;
        withdrawalAddresses[_validator] = _withdrawalAddress;
        reputations[_validator] = initialReputation;

        require(
            mOST.transferFrom(_validator, address(this), stakeMOSTAmount),
            "Failed to transfer mOST stake amount from a validator."
        );

        require(
            wETH.transferFrom(_validator, address(this), stakeWETHAmount),
            "Failed to transfer mOST stake amount from a validator."
        );
    }

    /**
     * @dev Function requires:
     *          - only consensus can call
     *          - a validator has joined
     */
    function slash(address _validator)
        external
        onlyConsensus
        hasJoined(_validator)
    {
        statuses[_validator] = ValidatorStatus.Slashed;
    }

    function logout(address _validator)
        external
        view
        onlyConsensus
    {
        // continue
    }
}
