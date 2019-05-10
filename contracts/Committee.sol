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
    
    /**
     * Sentinel pointer for marking the ending of circular,
     * linked-list of validators
     */
    address public constant SENTINEL_MEMBERS = address(0x1);

    /** Sentinel distance */
    bytes32 public constant SENTINEL_DISTANCE = bytes32(0x1111111111111111111111111111111111111111111111111111111111111111);

    /* Storage */

    /** Consensus contract for which this committee was formed. */
    address public consensus;

    /** Committee size */
    uint256 public committeeSize;

    /** Proposal under consideration */
    bytes32 proposal;

    /** Shuffle to validators in hashed space */
    bytes32 dislocation;

    /** Committee members */
    mapping(address => address) public members;

    /**
     * Committee members count
     * counts members entered and reaches maximum at committeSize
     */
    uint256 public count;

    modifier onlyConsensus()
    {
        require(msg.sender == consensus,
            "Only the consensus contract can call this fucntion.");
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
        require(_commiteeSize != 0,
            "Committee size must not be zero.");
        require(_dislocation != 0,
            "Dislocation must not be zero.");
        require(_proposal != 0,
            "Proposal must not be zero.");

        /** creator of committee is consensus */
        consensus = msg.sender;

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
        returns (bool)
    {
        require(_validator != SENTINEL_MEMBERS,
            "Validator address must not be sentinel.");
        require(members[_validator] == address(0) ,
            "Validator must not already have entered.");
        require(members[_furtherMember] != address(0),
            "Further validator must be in the committee.");
        
        // calculate the dislocated distance of the validator to the proposal
        dValidator = distance(shuffle(_validator), proposal);

        if (_furtherMember == SENTINEL_MEMBERS) {
            // Sentinel is always at maximum distance
            dFurtherMember = SENTINEL_DISTANCE;
        } else {
            // (re-)calculate the dislocated distance of the further member to the proposal
            dFurtherMember = distance(shuffle(_furtherMember), proposal);
        }

        require(dValidator < dFurtherMember,
            "Validator must be nearer than further away present validator.");

        // check whether other members are further removed.
        // loop over maximum size of committee; note, when providing the
        // correct _furtherMember this loop should execute only once and break;
        // the loop provides fall-back for transaction re-ordering as multiple validators
        // attempt to enter simultaneously.
        for (uint256 i = 0; i < committeeSize; i++) {
            // get address of nearer member
            address nearerMember = members[_furtherMember];
            if (nearerMember == SENTINEL_MEMBERS) {
                // validator is nearest to proposal currently in the committee;
                // enter validator as a member and return
                insertMember(_validator, SENTINEL_MEMBERS, _furtherMember);
                return true;
            }

            // calculate the distance of the preceding member, its distance should be less
            // than the validator's however, correct if not the case.
            dNearerMember = distance(shuffle(nearerMember), proposal);
            if (dNearerMember > dValidator) {
                // validator is nearer to the proposal than the supposedly nearer validator,
                // so move validator closer
                _furtherMember = nearerMember;
            } else {
                // validator has found its correct further validator
                insertMember(_validator, nearerMember, _furtherMember);
                return true;
            }
        }
        assert(false, "The committee is not correctly constructed.");
    }

    /* Private functions */

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
        // popped off again; but also note that a sensible actor will never
        // enter a validator that doesn't belong in the group, and so incurs
        // his own cost if he adds an wrong member when the group is already full.
        members[_member] = _previousMember;
        members[_nextMember] = _member;
        increaseCount();
    }

    function increaseCount()
        private
        returns (uint256 count_)
    {
        count = count.add(1);
        if (count > commiteeSize) {
            // member count in committee has reached desired size
            // remove furthest member
            popFurthestMember();
        }
        assert(count <= committeeSize,
            "Count must be equal or less than committeeSize.");
    }

    function popFurthestMember()
        private
    {
        assert(count > 0, "Members list should not be empty");
        address furthestMember = members[SENTINEL_MEMBERS];
        if (furthestMember != SENTINEL_MEMBERS) { // linked-list is not empty
            address secondFurthestMember = members[furthestMember];
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
            abi.encodePacked(
                _validator,
                dislocation
            )
        );
    }

    /** Distance metric for sorting validators */
    function distance(bytes32 _a, bytes32 _b)
        private
        returns (bytes32 distaince_)
    {
        // return _a XOR _b as a distance
        distance_ = _a ^ _b;
    }
}
}
