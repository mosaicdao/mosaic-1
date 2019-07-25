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

import "../consensus/ConsensusModule.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


/**
 * @title Committee
 * @author Benjamin Bollen - <ben@ost.com>
 */
contract Committee is ConsensusModule {

    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /**
     * Sentinel pointer for marking the ending of circular,
     * linked-list of validators.
     */
    address public constant SENTINEL_MEMBERS = address(0x1);

    /** Sentinel set to maximum distance from problem. */
    uint256 public constant SENTINEL_DISTANCE = uint256(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );

    /**
     * Committee formation cooldown period allows for objections to be
     * raised against the members entered into committee. After cooldown
     * without objections the committee is active.
     */
    uint256 public constant COMMITTEE_FORMATION_COOLDOWN = uint256(50);

    /** Timeout for accepting commits from members. About a day on Ethereum. */
    uint256 public constant COMMITTEE_COMMIT_PHASE_TIMEOUT = uint256(5760);

    /**
     * Timeout for revealing positions of members. About two hours on Ethereum.
     */
    uint256 public constant COMMITTEE_REVEAL_PHASE_TIMEOUT = uint256(480);

    /** A super-majority fraction numerator used for reaching consensus. */
    uint256 public constant COMMITTEE_SUPER_MAJORITY_NUMERATOR = uint256(2);

    /** A super-majority fraction denominator used for reaching consensus. */
    uint256 public constant COMMITTEE_SUPER_MAJORITY_DENOMINATOR = uint256(3);

    // @qn (pro): What is this for?
    bytes32 public constant COMMIT_DATA_UNAVAILABLE = keccak256(
        "COMMIT_DATA_UNAVAILABLE"
    );

    // @qn (pro): What is this for?
    bytes32 public constant COMMIT_REJECT_PROPOSAL = keccak256(
        "COMMIT_REJECT_PROPOSAL"
    );


    /* Enums */

    /** Committee status enum. */
    enum CommitteeStatus {
        /** While open, validators can enter as members. */
        Open,

        /** During cooldown, the member composition can be challenged. */
        Cooldown,

        /**
         * After unchallenged cooldown, the committee is active
         * and accepts sealed commits.
         */
        CommitPhase,

        /** Reveal positions and count. */
        RevealPhase,

        /** After voting completes the committee closes. */
        Closed,

        /**
         * Committee can become invalid if successfully challenged
         * during cooldown.
         */
        Invalid
    }


    /* Storage */

    /** Committee size */
    uint256 public committeeSize;

    /** Committee super majority */
    uint256 public quorum;

    /**
     * Committee members count.
     * Counts members entered and reaches maximum at committeeSize.
     */
    uint256 public memberCount;

    /** Submission count. */
    uint256 public submissionCount;

    /** Positions revealed count. */
    uint256 public totalPositionsCount;

    /** Count positions taken. */
    mapping(bytes32 => uint256) public positionCounts;

    /** Track position for which a quorum has been reached. */
    bytes32 public committeeDecision;

    /** Track array of positions taken. */
    bytes32[] public positionsTaken;

    /** Proposal under consideration. */
    bytes32 public proposal;

    /** Shuffle validators in hashed space with dislocation. */
    bytes32 public dislocation;

    /** Committee status. */
    CommitteeStatus public committeeStatus;

    /** Committee members */
    mapping(address => address) public members;

    /** Sealed commits submitted by members. */
    mapping(address => bytes32) public commits;

    /** Public positions taken by members. */
    mapping(address => bytes32) public positions;

    /**
     * Store the block height at which the committee can activate.
     * Height is set when cooldown commences.
     */
    uint256 public activationBlockHeight;

    /**
     * Store the block height at which commits can no longer be submitted.
     */
    uint256 public commitTimeOutBlockHeight;

    /**
     * Store the block height at which submitted commits can
     * no longer be revealed.
     */
    uint256 public revealTimeOutBlockHeight;

    /**
     * Store the member who initiated the cooldown, such that it
     * can be slashed should the committee formation be challenged.
     */
    address public memberInitiatedCooldown;


    /** Modifiers */

    modifier onlyMember() {
        require(
            members[msg.sender] != address(0),
            "Only members can call this function."
        );
        _;
    }

    modifier isOpen() {
        require(
            committeeStatus == CommitteeStatus.Open,
            "Committee formation must be open."
        );
        _;
    }

    modifier isCoolingDown() {
        require(
            committeeStatus == CommitteeStatus.Cooldown,
            "Committee formation must be cooling down."
        );
        _;
    }

    modifier isInCommitPhase() {
        require(
            committeeStatus == CommitteeStatus.CommitPhase,
            "Committee must be in the commit phase."
        );
        _;
    }

    modifier isInRevealPhase() {
        require(
            committeeStatus == CommitteeStatus.RevealPhase,
            "Committee must be in the reveal phase."
        );
        _;
    }

    modifier isDecided() {
        require(
            committeeDecision != bytes32(0),
            "Committee must have reached a quorum decision."
        );
        _;
    }


    /* Special Functions */

    /**
     * @notice Setups a new committee.
     *
     * @param _committeeSize Size of the committee. A minimum size is 3.
     * @param _dislocation Used to dislocate a validator position in a hashed
     *                     space before calculating a distance from a proposal.
     *                     A non-zero value is required.
     * @param _proposal A proposal for committee to evaluate. A non-zero value
     *                  is required.
     *
     * @dev Functions requires:
     *          -
     */
    constructor(
        uint256 _committeeSize,
        bytes32 _dislocation,
        bytes32 _proposal
    )
        ConsensusModule(msg.sender)
        public
    {
        require(
            _committeeSize >= 3,
            "Committee size must not be smaller than three."
        );

        require(
            _dislocation != 0,
            "Dislocation must not be zero."
        );

        require(
            _proposal != 0,
            "Proposal must not be zero."
        );

        committeeStatus = CommitteeStatus.Open;

        // Initialize the members linked-list as the empty set.
        members[SENTINEL_MEMBERS] = SENTINEL_MEMBERS;

        committeeSize = _committeeSize;

        dislocation = _dislocation;

        proposal = _proposal;

        // @qn (pro): In case of 7 quorum should be 4 or 5.
        quorum = _committeeSize * COMMITTEE_SUPER_MAJORITY_NUMERATOR /
            COMMITTEE_SUPER_MAJORITY_DENOMINATOR;
    }


    /* External functions */

    /** Enter a validator into the committee. */
    function enterCommittee(
        address _validator,
        address _furtherMember
    )
        external
        onlyConsensus
        isOpen
        returns (bool)
    {
        require(
            _validator != SENTINEL_MEMBERS,
            "Validator address must not be sentinel for committee member."
        );

        require(
            _validator != address(0),
            "Validator address must not be 0."
        );

        require(
            members[_validator] == address(0),
            "Validator must not already have entered."
        );

        require(
            members[_furtherMember] != address(0),
            "Further validator must be in the committee."
        );

        // Calculate the dislocated distance of the validator to the proposal.
        uint256 dValidator = distanceToProposal(_validator);

        // Sentinel is always at maximum distance.
        uint256 dFurtherMember = SENTINEL_DISTANCE;

        if (_furtherMember != SENTINEL_MEMBERS) {
            // Calculate the distance of the further member to the proposal.
            dFurtherMember = distanceToProposal(_furtherMember);
        }

        require(
            dValidator < dFurtherMember,
            "Validator must be nearer than further away present validator."
        );

        address furtherMember = _furtherMember;
        address nearerMember = members[_furtherMember];

        while (nearerMember != SENTINEL_MEMBERS) {
            // Calculate the distance of the nearer member, its distance
            // should be less than the validator's distance, however,
            // correct if not the case.
            uint256 dNearerMember = distanceToProposal(nearerMember);
            if (dNearerMember > dValidator) {
                // Validator is nearer to the proposal than the supposedly
                // nearer validator, so move validator closer to the proposal.
                furtherMember = nearerMember;
                nearerMember = members[nearerMember];
            } else {
                // Validator has found its correct nearer and further member
                // insertMember will pop members beyond committee size.
                insertMember(_validator, nearerMember, furtherMember);
                return true;
            }
        }

        insertMember(_validator, SENTINEL_MEMBERS, furtherMember);

        return true;
    }

    /**
     * @notice Initiate cool down for committee during which objections can
     *         be raised for the members entered in the committee.
     */
    function cooldownCommittee()
        external
        onlyMember
        isOpen
    {
        require(
            memberCount == committeeSize,
            "To close committee member count must equal committee size."
        );

        assert(activationBlockHeight == uint256(0));

        assert(memberInitiatedCooldown == address(0));

        memberInitiatedCooldown = msg.sender;

        activationBlockHeight = block.number + COMMITTEE_FORMATION_COOLDOWN;

        committeeStatus = CommitteeStatus.Cooldown;
    }

    /**
     * @notice Challenge committee members during cooldown period.
     *
     * @dev Must be called over Consensus to assert excluded member is
     *      a validator. Present a member that isn't present in the
     *      committee but should have been.
     *      Any excluded member invalidates the committee and member who
     *      initiated cooldown wrongly will be slashed.
     */
    function challengeCommittee(address _excludedMember)
        external
        onlyConsensus
        isCoolingDown
    {
        require(
            members[_excludedMember] == address(0),
            "Member should not already be in the committee."
        );

        uint256 dBoundary = distanceToProposal(members[SENTINEL_MEMBERS]);

        uint256 dExcludedMember = distanceToProposal(_excludedMember);

        // Member has been excluded only if distance to proposal is less
        // than the furthest committee member.
        require(
            dExcludedMember < dBoundary,
            "Member has been excluded."
        );

        committeeStatus = CommitteeStatus.Invalid;

        slashMember(memberInitiatedCooldown);
    }

    /**
     * @notice Activate committee after formation cooled down.
     *         After activation commits can be submitted.
     */
    function activateCommittee ()
        external
        onlyMember
        isCoolingDown
    {
        require(
            block.number > activationBlockHeight,
            "Committee formation must have cooled down before activation."
        );

        assert(commitTimeOutBlockHeight == 0);

        committeeStatus = CommitteeStatus.CommitPhase;
        commitTimeOutBlockHeight = block.number + COMMITTEE_COMMIT_PHASE_TIMEOUT;
    }

    /** @notice Members can submit their sealed commit. */
    function submitSealedCommit(bytes32 _sealedCommit)
        external
        onlyMember
        isInCommitPhase
    {
        require(
            _sealedCommit != bytes32(0),
            "Sealed commit cannot be null."
        );

        require(
            commits[msg.sender] == bytes32(0),
            "Member can only commit once."
        );

        commits[msg.sender] = _sealedCommit;

        submissionCount = submissionCount.add(1);

        tryStartRevealPhase();
    }

    /**
     * @notice Allow explicit closure of commit phase to trigger
     *         timeout condition.
     */
    function closeCommitPhase()
        external
        isInCommitPhase
    {
        tryStartRevealPhase();
    }

    function revealCommit(bytes32 _position, bytes32 _salt)
        external
        onlyMember
        isInRevealPhase
    {
        bytes32 commit = commits[msg.sender];

        require(
            commit != bytes32(0),
            "Commit cannot be null."
        );

        require(
            _position != bytes32(0),
            "Position cannot be null."
        );

        require(
            commit == sealPosition(_position, _salt),
            "Position must match previously submitted commit."
        );

        // note: _position can express among others data-unavailable,
        //       disagreement for PoC just register whether _position
        //       equals proposition.

        delete commits[msg.sender];

        positions[msg.sender] = _position;

        positionCounts[_position] = positionCounts[_position].add(1);
        if (positionCounts[_position] == 1) {
            // For each newly seen position, push it to the array.
            positionsTaken.push(_position);
        }
        if (positionCounts[_position] >= quorum) {
            // Sanity check, there should not be more than one position
            // that can achieve quorum.
            assert(
                committeeDecision == bytes32(0) ||
                committeeDecision == _position
            );
            positionsTaken.push(_position);
        }
        totalPositionsCount = totalPositionsCount.add(1);
    }

    function proposalAccepted()
        external
        view
        isDecided
        returns (bool)
    {
        return positionCounts[proposal] >= quorum;
    }

    function getMembers()
        external
        view
        returns (address[] memory)
    {
        uint256 c = 0;
        address currentMember = members[SENTINEL_MEMBERS];
        while(currentMember != SENTINEL_MEMBERS) {
            currentMember = members[currentMember];
            c ++;
        }
        assert(c == memberCount);
        address[] memory array = new address[](c);

        c = 0;
        currentMember = members[SENTINEL_MEMBERS];
        while(currentMember != SENTINEL_MEMBERS) {
            array[c] = currentMember;
            currentMember = members[currentMember];
            c ++;
        }
        return array;
    }


    /* Public Functions */

    function distanceToProposal(address _account)
        public
        view
        returns (uint256)
    {
        return distance(shuffle(_account), proposal);
    }


    /* Private functions */

    /**
     * Try to start the reveal phase by checking submission count or timeout.
     */
    function tryStartRevealPhase()
        private
    {
        if (submissionCount == memberCount ||
            block.number > commitTimeOutBlockHeight) {
            committeeStatus = CommitteeStatus.RevealPhase;
            revealTimeOutBlockHeight = block.number + COMMITTEE_REVEAL_PHASE_TIMEOUT;
        }
    }

    /**
     */
    function slashMember(address _member)
        private
        view
    {
        require(
            members[_member] != address(0),
            "Member must be in the committee to be slashed by committee."
        );

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
        // enter a validator that doesn't belong in the group, and so the
        // sender incurs his own cost if he adds a wrong member when the
        // group is already full.
        members[_member] = _previousMember;
        members[_nextMember] = _member;
        increaseCount();
    }

    function increaseCount()
        private
    {
        memberCount = memberCount.add(1);
        if (memberCount > committeeSize) {
            // member count in committee has reached desired size
            // remove furthest member
            popFurthestMember();
        }

        // Count must be equal or less than committeeSize.
        assert(memberCount <= committeeSize);
    }

    function popFurthestMember()
        private
    {
        // assert : members list should not be empty
        assert(memberCount > 0);
        address furthestMember = members[SENTINEL_MEMBERS];
        if (furthestMember != SENTINEL_MEMBERS) { // linked-list is not empty
            address secondFurthestMember = members[furthestMember];
            // remove furthestMember from linked-list
            members[SENTINEL_MEMBERS] = secondFurthestMember;
            delete members[furthestMember];
            memberCount = memberCount.sub(1);
        }
    }

    function shuffle(address _validator)
        public
        view
        returns (bytes32)
    {
        // return the dislocated position of the validator
        return keccak256(
            // TODO: note abi.encodePacked seems unneccesary,
            // is there an overhead?
            abi.encodePacked(
                _validator,
                dislocation
            )
        );
    }

    /** Distance metric for sorting validators */
    function distance(bytes32 _a, bytes32 _b)
        private
        pure
        returns (uint256 distance_)
    {
        // return _a XOR _b as a distance
        distance_ = uint256(_a ^ _b);
    }

    /** use the salt to seal the position */
    function sealPosition(bytes32 _position, bytes32 _salt)
        private
        pure
        returns (bytes32)
    {
        // return the sealed position
        return keccak256(
            // TODO: note abi.encodePacked seems unneccesary,
            // is there an overhead?
            abi.encodePacked(
                _position,
                _salt
            )
        );
    }
}
