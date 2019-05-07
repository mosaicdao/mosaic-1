pragma solidity ^0.5.0;

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

import "./EIP20I.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Consensus {

    using SafeMath for uint256;

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

    enum RoundStatus {
        /** Initial state after completion of previous commit */
        Committed,

        /** Proposal has been submitted */
        Proposed,

        /** Proposal has been validated */
        Validated,

        /** Committee for proposal has been formed */
        CommitteeFormed,

        /** Proposal has been precommitted to */
        Precommitted,

        /** Precommits have been revealed */
        Revealed
    }

    /** Validator structure */
    struct Validator {
        /** Address of previous validator in linked list */
        address previousValidator;

        /** Withdrawal address */
        address withdrawalAddress;

        /** Earned rewards */
        uint256 earnedRewards;

        /** Status */
        ValidatorStatus status;
    }

    /** Sentinel pointer for marking beginning and ending of circular linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);

    /** Sentinel pointer for marking beginning and ending of circular linked-list of commits */
    bytes32 public constant SENTINEL_COMMITS = bytes32(0x0000000000000000000000000000000000000000000000000000000000000001);

    /** EIP20 token for stakes and rewards for validators */
    EIP20I public valueToken;

    /** Required stake amount to join as a validator */
    uint256 public stakeAmount;

    /** Validator linked-list indexed by address */
    mapping(address => Validator) public validators;

    /** Commits indexed by height mapped to result hash */
    mapping(uint256 => bytes32) public commits;

    /** Latest height */
    uint256 head;

    /* Constructor */

    /**  */
    constructor(
        uint256 _stakeAmount
        //bytes32 _initialCommit
    )
        public
    {

        stakeAmount = _stakeAmount;
    }

    /* External functions */

    /** Submit a proposal */
    function submit(
        uint256 _height,
        bytes32 _proposal
    )
        external
        returns (bool)
    {

    }

    /** Validate the proposal */
    // In the toy model the validation can be done
    // during the submission call
 
    /** enter a validator into the committee */
    // at submission, future blockheight is set to function as seed
    // first entry in window of 256 most recent blocks containing assigned block
    function enterCommittee(address _validator)
        external
        returns (bool)
    {
        
    }

    /** Form committee from entries */
    // caller puts up stake, to be slashed if omitted entries?
    function formCommittee()
        external
        returns (bool)
    {

    }

    /** Precommit answer as committee member */
    function precommit(bytes32 _concealedVote)
        external
        returns (bool)
    {

    }

    /** Reveal answer */
    function reveal(bytes32 _salt)
        external
        returns (bool)
    {

    }

    /** Commit the answer */
    function commit()
        external
        returns (bool)
    {

    }

    /** Validator joins */
    function join(
        address _withdrawalAddress
    )
        external
        returns (bool)
    {

    }

    /** Validator logs out */
    function logout()
        external
        returns (bool)
    {

    }

    /** Validator withdraws */
    function withdraw()
        external
        returns (bool)
    {

    }

    /* Private functions */

    /** Add commit */
    function addCommit(uint256 _height, bytes32 _resultHash)
        private
    {
        require(_height == head, "Height must equal head.");
        head = head.add(1);
        // anchor resultHash in commits
        commits[_height] = _resultHash;

    }
}