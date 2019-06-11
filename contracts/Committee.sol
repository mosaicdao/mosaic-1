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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title Committee
 * @author Benjamin Bollen - <ben@ost.com>
 */
contract Committee {

    using SafeMath for uint256;

    /* Enum */

    /**
     * Committee status enum
     */
    enum CommitteeStatus {
        // while open, validators can enter as members
        Open,
        // during cooldown, the member composition can
        // be challenged
        Cooldown,
        // after unchallenged cooldown, the committee is active
        Active,
        // after voting completes the committee closes
        Closed,
        // committee can become invalid if successfully challenged
        // during cooldown
        Invalid
    }

    /* Constants */

    /**
     * Sentinel pointer for marking the ending of circular,
     * linked-list of validators
     */
    address public constant SENTINEL_MEMBERS = address(0x1);

    /**
     * Sentinel set to maximum distance removed from problem
     */
    uint256 public constant SENTINEL_DISTANCE = uint256(0x1111111111111111111111111111111111111111111111111111111111111111);

    /**
      * Committee formation cooldown period allows for objections to be
      * raised against the members entered into committee. After cooldown
      * without objections the committee is active.
      */
    uint256 public constant COMMITTEE_FORMATION_COOLDOWN = uint256(10);

    /* Storage */

    /** Consensus contract for which this committee was formed. */
    address public consensus;

    /** Committee size */
    uint256 public committeeSize;

    /** Proposal under consideration */
    bytes32 proposal;

    /** Shuffle validators in hashed space with dislocation */
    bytes32 dislocation;

    /** Committee status */
    CommitteeStatus public committeeStatus;

    /** Committee members */
    mapping(address => address) public members;

    /**
     * Committee members count
     * counts members entered and reaches maximum at committeSize
     */
    uint256 public count;

    /**
     * store the block height at which the committee can activate.
     * Height is set when cooldown commences.
     */
    uint256 public activationBlockHeight;

    /**
     * Store the member who initiated the cooldown, such that it
     * can be slashed should the committee formation be challenged.
     */
    address public memberInitiatedCooldown;

    modifier onlyConsensus()
    {
        require(msg.sender == consensus,
            "Only the consensus contract can call this fucntion.");
        _;
    }

    modifier onlyMember()
    {
        require(members[msg.sender] != address(0),
            "Only members can call this function.");
        _;
    }

    modifier isOpen()
    {
        require(committeeStatus == CommitteeStatus.Open,
            "Committee formation must be open.");
        _;
    }

    modifier isCoolingDown()
    {
        require(committeeStatus == CommitteeStatus.Cooldown,
            "Committee formation must be cooling down.");
        _;
    }

    /* Constructor */

    /**
     * @notice Setup a new committee
     */
    constructor(
        uint256 _committeeSize,
        bytes32 _dislocation,
        bytes32 _proposal
    )
        public
    {
        require(_committeeSize != 0,
            "Committee size must not be zero.");
        require(_dislocation != 0,
            "Dislocation must not be zero.");
        require(_proposal != 0,
            "Proposal must not be zero.");

        /** creator of committee is consensus */
        /** committee created by Consensus contract */
        consensus = msg.sender;
        committeeStatus = CommiteeStatus.Open;

        // initialize the members linked-list as the empty set
        members[SENTINEL_MEMBERS] = SENTINEL_MEMBERS;
        committeeSize = _committeeSize;
        dislocation = _dislocation;
        proposal = _proposal;
    }

    /* External functions */

    /** enter a validator into the Committee */
    function enterCommittee(address _validator, address _furtherMember)
        external
        onlyConsensus
        isOpen
        returns (bool)
    {
        require(_validator != SENTINEL_MEMBERS,
            "Validator address must not be sentinel for committee member.");
        require(members[_validator] == address(0),
            "Validator must not already have entered.");
        require(members[_furtherMember] != address(0),
            "Further validator must be in the committee.");

        // calculate the dislocated distance of the validator to the proposal
        uint256 dValidator = distance(shuffle(_validator), proposal);

        // Sentinel is always at maximum distance
        uint256 dFurtherMember = SENTINEL_DISTANCE;
        if (_furtherMember != SENTINEL_MEMBERS) {
            // calculate the distance of the further member to the proposal
            dFurtherMember = distance(shuffle(_furtherMember), proposal);
        }

        require(dValidator < dFurtherMember,
            "Validator must be nearer than further away present validator.");

        // check whether other members are further removed.
        // loop over maximum size of committee; note, when providing the
        // correct furtherMember this loop should execute only once and break;
        // the loop provides fall-back for transaction re-ordering as multiple validators
        // attempt to enter simultaneously and if the final furthertMember wouldn't have entered yet.
        address furtherMember = _furtherMember;
        for (uint256 i = 0; i < committeeSize; i++) {
            // get address of nearer member
            address nearerMember = members[furtherMember];
            if (nearerMember == SENTINEL_MEMBERS) {
                // validator is nearest to proposal currently in the committee;
                // enter validator as a member and return
                insertMember(_validator, SENTINEL_MEMBERS, furtherMember);
                return true;
            }

            // calculate the distance of the preceding member, its distance should be less
            // than the validator's distance, however, correct if not the case.
            uint256 dNearerMember = distance(shuffle(nearerMember), proposal);
            if (dNearerMember > dValidator) {
                // validator is nearer to the proposal than the supposedly nearer validator,
                // so move validator closer to the proposal
                furtherMember = nearerMember;
            } else {
                // validator has found its correct nearer and further member
                insertMember(_validator, nearerMember, furtherMember);
                return true;
            }
        }
        // TODO: improve implementation to remove this assert;
        // this line should be unreachable.
        assert(false);
    }

    /**
     * Initiate cool down for committee during which objections can be raised
     * for the members entered in the committee.
     */
    function cooldownCommittee()
        external
        onlyMember
        isOpen
    {
        require(count == committeeSize,
            "To close committee member count must equal committee size.");
        assert(activationBlockHeight == 0);
        assert(memberInitiatedCooldown == address(0));
        memberInitiatedCooldown = msg.sender;
        activationBlockHeight = block.number + COMMITTEE_FORMATION_COOLDOWN;
        committeeStatus = CommitteeStatus.Cooldown;
    }

    /**
     * Challenge committee members during cooldown period.
     * Must be called over Consensus to assert excluded member is a validator.
     * Present a member that isn't present in the committee but should have been.
     */
    function challengeCommittee(address _excludedMember)
        external
        onlyConsensus
        isCoolingDown
    {
        require(members[_excludedMember] == address(0),
            "Member should not already be in the committee.");
        uint256 dBoundary = distance(shuffle(members[SENTINEL_MEMBERS]), proposal);
        uint256 dExcludedMember = distance(shuffle(_excludedMember), proposal);
        require(dExcludedMember < dBoundary,
            "Member has been excluded only if distance to proposal is less than the furthest committee member.");
        committeeStatus = CommitteeStatus.Invalid;
        slashMember(memberInitiatedCooldown);
    }
    // once committee is filled, ie. reached committee size
    // put up a deposit to seal committee; can be slashed by anyone
    // presenting a validator that should have entered but didnt
    /**
     * Form committee when the validators closest to the proposal
     * have been entered as members of the committee
     */
    function formCommittee ()
        external
        onlyMember
    {

    }


    /* Private functions */

    /**
     */
    function slashMember(address _member)
        private
    {
        require(members[_member] != address(0),
            "Member must be in the committee to be slashed by committee.");
        // TODO: remove member from committee? or is committee now invalid?
        // TODO: implement consensus interface to slash from committee
        // consensus.slashValidator(_member);
    }
    /**
     * Insert member into commitee
     * @dev important, this private function does *not* perform
     *      sanity checks anymore; must be done by caller
     */
    function insertMember(
        address _member,
        address _previousMember,
        address _nextMember
    )
        private
    {
        // note that we could check whether the member inserted would be
        // popped off later when checking the count;
        // but also note that a sensible actor will never
        // enter a validator that doesn't belong in the group, and so the sender incurs
        // his own cost if he adds a wrong member when the group is already full.
        members[_member] = _previousMember;
        members[_nextMember] = _member;
        increaseCount();
    }

    function increaseCount()
        private
        returns (uint256 count_)
    {
        count = count.add(1);
        if (count > committeeSize) {
            // member count in committee has reached desired size
            // remove furthest member
            popFurthestMember();
        }

        // Count must be equal or less than committeeSize.
        assert(count <= committeeSize);
    }

    function popFurthestMember()
        private
    {
        // assert : members list should not be empty
        assert(count > 0);
        address furthestMember = members[SENTINEL_MEMBERS];
        if (furthestMember != SENTINEL_MEMBERS) { // linked-list is not empty
            address secondFurthestMember = members[furthestMember];
            // remove furthestMember from linked-list
            members[SENTINEL_MEMBERS] = secondFurthestMember;
            delete members[furthestMember];
            count = count.sub(1);
        }
    }

    function shuffle(address _validator)
        private
        returns (bytes32)
    {
        // return the dislocated position of the validator
        return keccak256(
            // TODO: note abi.encodePacked seems unneccesary, is there an overhead?
            abi.encodePacked(
                _validator,
                dislocation
            )
        );
    }

    /** Distance metric for sorting validators */
    function distance(bytes32 _a, bytes32 _b)
        private
        returns (uint256 distance_)
    {
        // return _a XOR _b as a distance
        distance_ = uint256(_a ^ _b);
    }
}
