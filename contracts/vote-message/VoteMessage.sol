pragma solidity >=0.5.0 <0.6.0;

// Copyright 2020 OpenST Ltd.
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

contract VoteMessage {

    /* Constants */

    /** EIP-712 type hash for a Vote Message */
    bytes32 public constant VOTE_MESSAGE_TYPEHASH = keccak256(
        "VoteMessage(bytes32 transitionHash,bytes32 sourceBlockHash,bytes32 targetBlockHash,uint256 sourceBlockNumber,uint256 targetBlockNumber)"
    );


    /* Internal Functions */

    /**
     * @notice Takes the VoteMessage parameters and returns
     *        the typed VoteMessage hash.
     */
    function hashVoteMessage(
        bytes32 _domainSeparator
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                VOTE_MESSAGE_TYPEHASH,
                _transitionHash,
                _source,
                _target,
                _sourceBlockNumber,
                _targetBlockNumber
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                _domainSeparator,
                typedVoteMessageHash
            )
        );
    }
}
