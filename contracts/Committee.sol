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

/**
 * @title Committee
 */
contract Committee {

    /** Sentinel pointer for marking beginning and ending of circular linked-list of validators */
    address public constant SENTINEL_MEMBERS = address(0x1);

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

        committeeSize = _committeeSize;
        dislocation = _dislocation;
        proposal = _proposal;
    }

    /* External functions */

    /** enter a validator into the Committee */
    function enterCommittee(address _validator, address _furtherValidator)
        external
        onlyConsensus
        returns (bool)
    {
        require(members[_validator] == address(0),
            "Validator must not already have entered.");
        require(members[_furtherValidator] != address(0),
            "Further validator must be in the committee.");
        
        dValidator = distance(shuffle(_validator), proposal);
        dFurtherValidator = distance(shuffle(_furtherValidator), proposal);

        require(dValidator < dFurtherValidator,
            "Validator must be nearer than further away present validator.);
    }

    /* Private functions */

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
