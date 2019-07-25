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

import "../EIP20I.sol";
import "../reputation/ReputationI.sol";
import "../committee/Committee.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Consensus {

    /* Storage */

    using SafeMath for uint256;

    /** Committee formation block delay */
    uint256 public constant COMMITTEE_FORMATION_DELAY = uint256(35);

    /** EIP20 token for stakes and rewards for validators */
    EIP20I public valueToken;

    /** Required stake amount to join as a validator */
    uint256 public stakeAmount;

    /** Committee size */
    uint256 public committeeSize;

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
        EIP20I _valueToken,
        uint256 _stakeAmount,
        uint256 _committeeSize
    )
        public
    {
        require(
            address(_valueToken) != address(0),
            "Value token address is 0."
        );

        require(
            _stakeAmount > 0,
            "Stake amount is 0."
        );

        require(
            _committeeSize > 0,
            "Committee size is 0."
        );

        valueToken = _valueToken;

        stakeAmount = _stakeAmount;

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
