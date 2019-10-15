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

    /**
     * Timeout for accepting commits from members
     * The proposed value is uint256(5760) which is about a day on Ethereum.
     * Lowering it 10 times to ease testing.
     * @qn (pro): Should we move this into the constructor as an argument?
     */
    uint256 public constant COMMITTEE_COMMIT_PHASE_TIMEOUT = uint256(576);

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


    /* External functions */

    function setup(
        address _consensus,
        uint256 _committeeSize,
        bytes32 _dislocation,
        bytes32 _proposal
    )
        external
    {
        require(
            committeeSize == 0 && proposal == bytes32(0),
            "Committee is already setup."
        );

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

        consensus = _consensus;

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

    /**
     * @notice Enters a `_validator` into the committee.
     *
     * @dev Function requires:
     *          - only the consensus contract can call
     *          - the committe's status is open
     *          - the specified validator distance from the proposal is less
     *            than the specified further member one.
     *
     * @param _validator Validator address to enter.
     *                   The specified address:
     *                      - is not 0
     *                      - is not the member-sentinel
     *                      - has not been already entered
     * @param _furtherMember Further member (compared with the validator)
     *                       address. The specified address:
     *                          - has been already entered
     */
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
     * @notice Initiates cool down for the committee during which objections can
     *         be raised for the members entered in the committee.
     *
     * @dev Function requires:
     *          - only a member can call
     *          - the committee is in an open state
     *          - members' count in the committee is equal to the committee's
     *            size
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
     *
     * @param _excludedMember Excluded member of the committee. Requires that
     *                        the specified account is not a member and
     *                        that its distance from the proposal is less than
     *                        furthest committee member distance.
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

        // @qn (pro): We can remove this call and let consensus to slash
        // a member that has wrongly initiated cooldown.
        slashMember(memberInitiatedCooldown);
    }

    /**
     * @notice Activates the committee after formation cooled down.
     *         After activation commits can be submitted.
     *
     * @dev Function requires:
     *          - only member can call
     *          - committee is in cooling down status
     *          - committee activation block height is reached
     */
    function activateCommittee()
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

    /**
     * @notice Members can submit their sealed commit.
     *         The function transitions the committee to the reveal phase
     *         in either of the below conditions:
     *              - all members have submitted their sealed commits
     *              - commit timeout block height has been reached
     *
     * @dev Function requires:
     *          - committee is in commit phase
     *          - only member can call
     *          - member can commit only once
     *
     * @param _sealedCommit Sealed commit of a member. Non-zero value is
     *                      required.
     */
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
     *
     * @dev Function requires:
     *          - committee is in commit phase
     */
    function closeCommitPhase()
        external
        isInCommitPhase
    {
        tryStartRevealPhase();
    }

    /**
     * @notice Members reveal their positions and salts.
     *
     * @dev Function requires:
     *          - only member can call
     *          - committee is in reveal phase
     *          - member has submitted and has not reveal its commit yet
     *          - position and salt must match with sealed commit
     *
     * @param _position Position of the member's commit.
     *                  Non-zero value is required.
     * @param _salt Salt of the member's submitted commit.
     */
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
            committeeDecision = _position;
        }

        totalPositionsCount = totalPositionsCount.add(1);
    }

    /** @notice Returns true if the proposal reached the quorum. */
    function proposalAccepted()
        external
        view
        returns (bool)
    {
        return positionCounts[proposal] >= quorum;
    }

    /** @notice Returns an array of committee members. */
    function getMembers()
        external
        view
        returns (address[] memory)
    {
        uint256 c = 0;
        address currentMember = members[SENTINEL_MEMBERS];
        while(currentMember != SENTINEL_MEMBERS) {
            currentMember = members[currentMember];
            c++;
        }
        assert(c == memberCount);
        address[] memory array = new address[](c);

        c = 0;
        currentMember = members[SENTINEL_MEMBERS];
        while(currentMember != SENTINEL_MEMBERS) {
            array[c] = currentMember;
            currentMember = members[currentMember];
            c++;
        }
        return array;
    }


    /* Public Functions */

    /**
     * @notice Calculates a distance of the specified `_account` from the
     *         `proposal`. The `_account` is shuffled/dislocated in the
     *         hashed space before calculating a distande.
     *
     * @param _account The account address to calculate distance from the
     *                 proposal.
     *
     */
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
        // @qn (pro): Should reveal phase start if submitted seals' amount is
        //            less then the quorum amount.
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

    /**
     * @notice Shuffles (dislocates) `_validator` in the hashed space using
     *         `dislocation` member.
     *
     * @param _validator The validator address to shuffle.
     *
     * @return Shuffled value of the specified `_validator`.
     */
    function shuffle(address _validator)
        public
        view
        returns (bytes32)
    {
        // Returns the dislocated position of the validator.
        return keccak256(
            // TODO: note abi.encodePacked seems unneccesary,
            // is there an overhead?
            abi.encodePacked(
                _validator,
                dislocation
            )
        );
    }

    /**
     * @notice Returns a distance (by using XOR) between `_a` and `_b`
     *         for sorting validators.
     */
    function distance(bytes32 _a, bytes32 _b)
        private
        pure
        returns (uint256 distance_)
    {
        // Returns _a XOR _b as a distance.
        distance_ = uint256(_a ^ _b);
    }

    /** Uses the salt to seal the position. */
    function sealPosition(bytes32 _position, bytes32 _salt)
        private
        pure
        returns (bytes32)
    {
        // Returns the sealed position.
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
