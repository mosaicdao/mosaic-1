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

contract MessageBase {

    /* Constants */

    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        abi.encode(
            "Message(bytes32 intentHash,uint256 nonce,uint256 gasPrice,uint256 gasLimit,address sender)"
        )
    );
    //TODO: is domain separator needed? This is not used for signing.

    /* Structs */

    /** A Message is sent between gateways. */
    struct Message {

        /** Intent hash of specific request type. */
        bytes32 intentHash;

        /** Nonce of the sender. */
        uint256 nonce;

        /** Gas price that sender will pay for reward. */
        uint256 gasPrice;

        /** Gas limit that sender will pay. */
        uint256 gasLimit;

        /** Address of the message sender. */
        address sender;
    }


    /* Internal Functions */

    /**
     * @notice Generate message hash from the input params
     * @param _message Message params.
     * @return messageHash_ Message hash.
     */
    function messageHash(
        Message memory _message
    )
        internal
        pure
        returns (bytes32 messageHash_)
    {
        messageHash_ = keccak256(
            abi.encode(
                MESSAGE_TYPEHASH,
                _message.intentHash,
                _message.nonce,
                _message.gasPrice,
                _message.gasLimit,
                _message.sender
            )
        );
    }
}
