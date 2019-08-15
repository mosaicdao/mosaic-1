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
    uint256 public constant COMMITTEE_FORMATION_DELAY = uint256(14);

    /** Committee formation mixing length */
    uint256 public constant COMMITTEE_FORMATION_LENGTH = uint256(7);

    /** Core status Halted */
    bytes20 public constant CORE_STATUS_HALTED = bytes20(keccak256("CORE_STATUS_HALTED"));

    /** Core status Corrupted */
    bytes20 public constant CORE_STATUS_CORRUPTED = bytes20(keccak256("CORE_STATUS_CORRUPTED"));


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
    mapping(bytes32 /* proposal */ => address /* committee */) public proposals;

    /** Proposals mapped to Committees */
    mapping(bytes32 => address) public committees;

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
    }

    /* External functions */

    // /** Randomize committee to start formation */
    // function randomizeCommittee()
    //     external
    //     returns (bool)
    // {
    //     require(committeeFormationHash == 0,
    //         "Committee formation hash is already set.");

    //     require(block.number > committeeFormationHeight,
    //         "Block height must be higher than set committee formation height.");
    //     require(block.number - 256 < committeeFormationHeight,
    //         "Committee formation height must be in 256 most recent blocks.");

    //     committeeFormationHash = blockhash(committeeFormationHeight);
    //     assert(committeeFormationHash != 0);
    // }

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

}
