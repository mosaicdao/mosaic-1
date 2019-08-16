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

import "../EIP20I.sol";
import "../reputation/ReputationI.sol";
import "../committee/Committee.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Consensus {

    using SafeMath for uint256;


    /* Constants */

    /** Committee formation block delay */
    uint256 public constant COMMITTEE_FORMATION_DELAY = uint8(14);

    /** Committee formation mixing length */
    uint256 public constant COMMITTEE_FORMATION_LENGTH = uint8(7);

    /** Core status Halted */
    bytes20 public constant CORE_STATUS_HALTED = bytes20(keccak256("CORE_STATUS_HALTED"));

    /** Core status Corrupted */
    bytes20 public constant CORE_STATUS_CORRUPTED = bytes20(keccak256("CORE_STATUS_CORRUPTED"));

    /** Sentinel pointer for marking end of linked-list of committees */
    address public constant SENTINEL_COMMITTEES = address(0x1);


    /* Structs */

    /** Precommit from core for a next metablock */
    struct Precommit {
        bytes32 proposal;
        uint256 committeeFormationBlockHeight;
    }


    /* Storage */

    /** EIP20 mOST for stakes and rewards for validators */
    EIP20I public mOST;

    /** Required stake amount in mOST to join as a validator */
    uint256 public stakeMOSTAmount;

    /** Required stake amount in ETH to join as a validator */
    uint256 public stakeETHAmount;

    /** Committee size */
    uint256 public committeeSize;

    /** Minimum number of validators that must join a created core to open */
    uint256 public minCoreSize;

    /** Maximum number of validatirs that can join in a core */
    uint256 public maxCoreSize;

    /** Gas target delta to open new metablock */
    uint256 public gasTargetDelta;

    /** Coinbase split percentage */
    uint256 public coinbaseSplitPercentage;

    /** Block hash of heads of Metablockchains */
    mapping(bytes20 /* chainId */ => bytes32 /* MetablockHash */) public metablockHeaderTips;

    /** Core statuses */
    mapping(address /* core */ => bytes20 /* coreStatus */) public coreStatuses;

    /** Assigned core for a given chainId */
    mapping(bytes20 /* chainId */ => address /* core */) public assignments;

    /** Precommitted proposals from core for a metablockchain */
    mapping(address /* core */ => Precommit) public precommits;

    /** Proposals under consideration of a committee */
    mapping(bytes32 /* proposal */ => Committee /* committee */) public proposals;

    /** Linked-list of committees */
    mapping(address => address) public committees;

    /** Reputation contract for validators */
    ReputationI public reputation;


    /* Modifiers */

    modifier onlyValidator()
    {
        require(
            reputation.isActive(msg.sender),
            "Validator must be active in the reputation contract."
        );

        _;
    }

    modifier onlyCore()
    {
        require(
            isCore(msg.sender),
            "Caller must be an active core."
        );

        _;
    }


    /* Special Member Functions */

    constructor(
        EIP20I _mOST,
        uint256 _stakeMOSTAmount,
        uint256 _stakeETHAmount,
        uint256 _committeeSize
    )
        public
    {
        require(
            address(_mOST) != address(0),
            "mOST address is 0."
        );

        require(
            _stakeMOSTAmount.add(_stakeETHAmount) > 0,
            "Total stake amount is 0."
        );

        require(
            _committeeSize > 0,
            "Committee size is 0."
        );

        mOST = _mOST;

        stakeMOSTAmount = _stakeMOSTAmount;

        stakeETHAmount = _stakeETHAmount;

        committeeSize = _committeeSize;

        committees[SENTINEL_COMMITTEES] = SENTINEL_COMMITTEES;
    }


    /* External functions */

    /** enter a validator into the committee */
    // at submission, future blockheight is set to function as seed
    // first entry in window of 256 most recent blocks containing assigned block
    function enterCommittee(address /*_validator*/, address /*_closerValidator*/)
        external
        view
        returns (bool)
    {
        // require(committeeFormationHash != 0,
        //     "Randomization hash must be set");

    }

    /** Core register precommit */
    function registerPrecommit(bytes32 _proposal)
        external
        onlyCore
        returns (bool)
    {
        // onlyCore asserts msg.sender is active core
        Precommit storage precommit = precommits[msg.sender];
        require(
            precommit.proposal == bytes32(0),
            "There already exists a precommit of the core."
        );
        precommit.proposal = _proposal;
        precommit.committeeFormationBlockHeight = block.number.add(uint256(COMMITTEE_FORMATION_DELAY));
    }

    /**  */
    function formCommittee(address _core)
        external
        returns (bool)
    {
        Precommit storage precommit = precommits[_core];
        // note it should suffice to check only one property for existance, in PoC asserting both
        require(
            precommit.proposal != bytes32(0) &&
            precommit.committeeFormationBlockHeight != uint256(0),
            "There does not exist a precommitment of the core to a proposal"
        );
        require(
            block.number > precommit.committeeFormationBlockHeight,
            "Block height must be higher than set committee formation height."
        );
        require(
            block.number
                .sub(uint256(COMMITTEE_FORMATION_LENGTH))
                .sub(uint256(256)) < precommit.committeeFormationBlockHeight,
            "Committee formation blocksegment length must be in 256 most recent blocks."
        );
        uint256 segmentHeight = precommit.committeeFormationBlockHeight;
        bytes32[] memory seedGenerator = new bytes32[](uint256(COMMITTEE_FORMATION_LENGTH));
        for (uint8 i = 0; i < COMMITTEE_FORMATION_LENGTH; i++) {
            seedGenerator[i] = blockhash(segmentHeight);
            segmentHeight = segmentHeight.sub(1);
        }
        bytes32 seed = keccak256(
            abi.encodePacked(seedGenerator)
        );

        startCommittee(seed, precommit.proposal);
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


    /* Internal functions */

    /**  */
    function isCore(address _core)
        internal
        view
        returns (bool)
    {
        bytes20 status = coreStatuses[_core];
        return status != bytes20(0) &&
            status != CORE_STATUS_HALTED &&
            status != CORE_STATUS_CORRUPTED;
    }

    /** insert new Committee */
    function startCommittee(bytes32 _dislocation, bytes32 _proposal)
        internal
    {
        require(
            proposals[_proposal] != Committee(0),
            "There already exists a committee for the proposal."
        );
        // TODO: implement proxy pattern
        Committee committee_ = new Committee(committeeSize, _dislocation, _proposal);
        committees[address(committee_)] = committees[SENTINEL_COMMITTEES];
        committees[SENTINEL_COMMITTEES] = address(committee_);

        proposals[_proposal] = committee_;
    }
}
