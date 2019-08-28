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

    uint256 public constant MAX_UINT256 = uint256(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );



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


    /* Structs */

    struct ValidatorInfo {
        ValidatorStatus status;
        address withdrawalAddress;
        uint256 reputation;
        uint256 reward;
        uint256 withdrawableReward;
        uint256 withdrawalBlockHeight;
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

    /** Cooldown period to withdraw after validator has logged out. */
    uint256 public withdrawalCooldownPeriodInBlocks;

    /** Validators info */
    mapping(address => ValidatorInfo) public validators;


    /* Modifiers */

    modifier isActive(address _validator)
    {
        require(
            validators[_validator].status == ValidatorStatus.Staked,
            "Validator is not active."
        );

        _;
    }

    modifier hasJoined(address _validator)
    {
        require(
            validators[_validator].status != ValidatorStatus.Undefined,
            "Validator has not joined."
        );

        _;
    }

    modifier wasSlashed(address _validator)
    {
        require(
            validators[_validator].status == ValidatorStatus.Slashed,
            "Validator was not slashed."
        );

        _;
    }

    modifier wasNotSlashed(address _validator)
    {
        require(
            validators[_validator].status != ValidatorStatus.Slashed,
            "Validator was slashed."
        );

        _;
    }

    modifier hasLoggedOut(address _validator)
    {
        require(
            validators[_validator].status == ValidatorStatus.LoggedOut ||
            validators[_validator].status == ValidatorStatus.Withdrawn,
            "Validator has not logged out."
        );

        _;
    }

    modifier hasNotLoggedOut(address _validator)
    {
        require(
            validators[_validator].status != ValidatorStatus.LoggedOut &&
            validators[_validator].status != ValidatorStatus.Withdrawn,
            "Validator has not logged out."
        );

        _;
    }

    modifier withdrawalCooldownPeriodHasElapsed(address _validator)
    {
        require(
            block.number > validators[_validator].withdrawalBlockHeight,
            "Withdrawal cooldown period has not elapsed."
        );

        _;
    }

    modifier hasWithdrawn(address _validator)
    {
        require(
            validators[_validator].status == ValidatorStatus.Withdrawn,
            "Validator has not withdrawn."
        );

        _;
    }

    modifier hasNotWithdrawn(address _validator)
    {
        require(
            validators[_validator].status != ValidatorStatus.Withdrawn,
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
        uint256 _initialReputation,
        uint256 _withdrawalCooldownPeriodInBlocks
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
        _withdrawalCooldownPeriodInBlocks = _withdrawalCooldownPeriodInBlocks;
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
        ValidatorInfo storage v = validators[_validator];
        v.reputation = v.reputation.add(_delta);

        return v.reputation;
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
        ValidatorInfo storage v = validators[_validator];

        if (v.reputation < _delta) {
            v.reputation = 0;
        } else {
            v.reputation = v.reputation.sub(_delta);
        }

        return v.reputation;
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
        ValidatorInfo storage v = validators[_validator];

        v.reward = v.reward.add(_amount);

        v.withdrawableReward = v.withdrawableReward.add(
            (_amount * withdrawableRewardPercentage) / 100
        );
    }

    /**
     * @notice Withdraws the specified amount from a reward of a validator.
     *
     * @dev Function requiers:
     *          - only validator can call
     *          - validator has joined
     *          - validator was not slashed
     *          - validator has not withdrawn
     *          - the speciefied amount is not bigger than a withdrawable reward
     *            of a validator
     *
     * @param _amount An amount to withdraw.
     */
    function withdrawReward(uint256 _amount)
        external
        hasJoined(msg.sender)
        wasNotSlashed(msg.sender)
        hasNotWithdrawn(msg.sender)
    {
        ValidatorInfo storage v = validators[msg.sender];

        require(
            _amount <= v.withdrawableReward,
            "The specified amount is bigger than available withdrawable amount."
        );

        v.withdrawableReward = v.withdrawableReward.sub(
            _amount
        );

        v.reward = v.reward.sub(
            _amount
        );

        require(
            mOST.transfer(
                v.withdrawalAddress, _amount
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
            validators[_validator].status == ValidatorStatus.Undefined,
            "No validator can rejoin."
        );

        require(
            validators[_withdrawalAddress].status == ValidatorStatus.Undefined,
            "The specified withdrawal address was registered as validator."
        );

        require(
            validators[_validator].withdrawalAddress == address(0),
            "No validator can rejoin."
        );

        require(
            validators[_withdrawalAddress].withdrawalAddress == address(0),
            "The specified withdrawal address has been already used as validator."
        );

        ValidatorInfo storage v = validators[_validator];

        v.status = ValidatorStatus.Staked;
        v.withdrawalAddress = _withdrawalAddress;
        v.reputation = initialReputation;
        v.withdrawalBlockHeight = MAX_UINT256;

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
     * @notice Slashes validator.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - a validator has joined
     *          - a validator has not withdrawn
     *
     * TODO: The reward and stakes of a validator must be burned.
     */
    function slash(address _validator)
        external
        onlyConsensus
        hasJoined(_validator)
        hasNotWithdrawn(_validator)
    {
        ValidatorInfo storage v = validators[_validator];

        v.status = ValidatorStatus.Slashed;

        v.reward = 0;
        v.withdrawableReward = 0;
    }

    /**
     * @notice Logs out a validator.
     *
     * @dev Function requires:
     *          - only consensus can call
     *          - validator is active
     *
     * @param _validator A validator to log out.
     */
    function logout(address _validator)
        external
        onlyConsensus
        isActive(_validator)
    {
        ValidatorInfo storage v = validators[_validator];

        v.status = ValidatorStatus.LoggedOut;

        v.withdrawalBlockHeight = block.number.add(
            withdrawalCooldownPeriodInBlocks
        );
    }

    /**
     * @notice Withdraws a staked and rewarded values to a validator.
     *
     * @dev Function requires:
     *          - a validator has logged out
     *          - a validator was not slashed
     *          - a validator has not withdrawn
     *
     * @param _validator A validator to withdraw reward and stakes.
     */
    function withdraw(address _validator)
        external
        hasLoggedOut(_validator)
        wasNotSlashed(_validator)
        hasNotWithdrawn(_validator)
        withdrawalCooldownPeriodHasElapsed(_validator)
    {
        ValidatorInfo storage v = validators[_validator];

        v.status = ValidatorStatus.Withdrawn;

        uint256 rewardAmount = v.reward;

        v.reward = 0;
        v.withdrawableReward = 0;

        require(
            mOST.transfer(
                v.withdrawalAddress, stakeMOSTAmount.add(rewardAmount)
            ),
            "Failed to withdraw a staked and rewarded mOST amount."
        );

        require(
            wETH.transfer(
                v.withdrawalAddress, stakeWETHAmount
            ),
            "Failed to withdraw a staked wETH amount."
        );
    }
}
