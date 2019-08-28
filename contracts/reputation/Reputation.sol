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


    /* Enums */

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

    /** EIP20 mOST for stakes and rewards for validators. */
    EIP20I public mOST;

    /** EIP20 wETH for stakes and rewards for validators. */
    EIP20I public wETH;

    /** Required stake amount in mOST to join as a validator */
    uint256 public stakeMOSTAmount;

    /** Required stake amount in wETH to join as a validator */
    uint256 public stakeWETHAmount;

    /** A percentage from a reward that validator can withdraw. */
    uint256 withdrawableRewardPercentage;

    /** Initial reputation for the newly joined validator. */
    uint256 public initialReputation;

    /** Status */
    mapping(address => ValidatorStatus) public statuses;

    /** Withdrawal address */
    mapping(address => address) public withdrawalAddresses;

    /** Reputation earned */
    mapping(address => uint256) public reputations;

    /** Earned rewards */
    mapping(address => uint256) public rewards;

    /** A withdrawable rewards */
    mapping(address => uint256) public withdrawableRewards;


    /* Modifiers */

    modifier isActive(address _validator)
    {
        require(
            statuses[_validator] == ValidatorStatus.Staked,
            "Validator is not active."
        );

        _;
    }

    modifier wasSlashed(address _validator)
    {
        require(
            statuses[_validator] == ValidatorStatus.Slashed,
            "Validator was not slashed."
        );

        _;
    }

    modifier wasNotSlashed(address _validator)
    {
        require(
            statuses[_validator] != ValidatorStatus.Slashed,
            "Validator was slashed."
        );

        _;
    }

    modifier hasJoined(address _validator)
    {
        require(
            statuses[_validator] != ValidatorStatus.Undefined,
            "Validator has not joined."
        );

        _;
    }

    modifier hasWithdrawn(address _validator)
    {
        require(
            statuses[_validator] == ValidatorStatus.Withdrawn,
            "Validator has not withdrawn."
        );

        _;
    }

    modifier hasNotWithdrawn(address _validator)
    {
        require(
            statuses[_validator] != ValidatorStatus.Withdrawn,
            "Validator has withdrawn."
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
     *          - a withdrawable reward percentage is in [0, 100] range
     */
    constructor(
        address _consensus,
        EIP20I _mOST,
        uint256 _stakeMOSTAmount,
        EIP20I _wETH,
        uint256 _stakeWETHAmount,
        uint256 _withdrawableRewardPercentage,
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
            _withdrawableRewardPercentage <= 100,
            "Withdrawable reward percentage is not in valid range: [0, 100]."
        );

        mOST = _mOST;
        wETH = _wETH;
        stakeMOSTAmount = _stakeMOSTAmount;
        stakeWETHAmount = _stakeWETHAmount;
        initialReputation = _initialReputation;
        withdrawableRewardPercentage = _withdrawableRewardPercentage;
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
    function increaseReputation(address _validator, uint256 _delta)
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
    function decreaseReputation(address _validator, uint256 _delta)
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
     * @notice Rewards validator by the specified amount.
     *         Only fixed percentage (`withdrawableRewardPercentage`) from the
     *         rewarded amount is withdrawable by a validator. The remaining is
     *         locked in the contract and can be withdrawn only when validator
     *         has been logged out and cooling period has elapsed.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - a validator is active
     *
     * @param _validator A validator to reward.
     * @param _amount An amount to reward a validator.
     */
    function reward(
        address _validator,
        uint256 _amount
    )
        external
        onlyConsensus
        isActive(_validator)
    {
        rewards[_validator] = rewards[_validator].add(_amount);
        withdrawableRewards[_validator] = withdrawableRewards[_validator].add(
            (_amount * withdrawableRewardPercentage) / 100
        );
    }

    /**
     * @notice Withdraws the specified amount from a reward of a validator.
     *
     * @dev Function requiers:
     *          - only consensus can call
     *          - validator has joined
     *          - validator was not slashed
     *          - validator has not withdrawn
     *          - the speciefied amount is not bigger than a withdrawable reward
     *            of a validator
     *
     * @param _validator A validator address that requested a withdrawal.
     * @param _amount An amount to withdraw.
     */
    function withdrawReward(address _validator, uint256 _amount)
        external
        onlyConsensus
        hasJoined(_validator)
        wasNotSlashed(_validator)
        hasNotWithdrawn(_validator)
    {
        require(
            _amount <= withdrawableRewards[_validator],
            "The specified amount is bigger than available withdrawable amount."
        );

        withdrawableRewards[_validator] = withdrawableRewards[_validator].sub(
            _amount
        );

        require(
            mOST.transfer(
                withdrawalAddresses[_validator], _amount
            ),
            "Failed to transfer a reward amount to withdrawal address."
        );
    }

    /**
     * @dev Function requires:
     *          - only consensus can call
     *          - a validator address is not 0
     *          - a withdrawal address is not 0
     *          - a validator address is not same as its withdrawal address
     *          - a validator has not joined previously
     *          - a withdrawal address has not been used as a validator address
     *          - a withdrawal address has not been already used
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
            statuses[_withdrawalAddress] == ValidatorStatus.Undefined,
            "The specified withdrawal address was registered as validator."
        );

        require(
            withdrawalAddresses[_validator] == address(0),
            "No validator can rejoin."
        );

        require(
            withdrawalAddresses[_withdrawalAddress] == address(0),
            "The specified withdrawal address has been already used as validator."
        );

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

        // continue
        revert("Implementation is incomplete!");
    }

    function logout(address _validator)
        external
        view
        onlyConsensus
    {
        // continue
        revert("Implementation is incomplete!");
    }

    function withdraw(address _validator)
        external
        onlyConsensus
        hasJoined(_validator)
        wasNotSlashed(_validator)
        hasNotWithdrawn(_validator)
    {
        // continue
        revert("Implementation is incomplete!");
    }
}
