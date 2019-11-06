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

import "../version/MosaicVersion.sol";

contract MessageBox is MosaicVersion {

    /* Constants */

    /** EIP-712 domain separator name for Core */
    string public constant DOMAIN_SEPARATOR_NAME = "Message-Gateway";

    /** EIP-712 domain separator for Core */
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,bytes20 chainId,address verifyingContract,bytes32 salt)"
    );

    /** Message type hash */
    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        abi.encode(
            "Message(bytes32 intentHash,uint256 nonce,uint256 gasPrice,uint256 gasLimit,address sender)"
        )
    );

    /**
     * @notice Generate message hash from the input params
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _gasPrice Gas price.
     * @param _gasLimit Gas limit.
     * @param _sender Sender address.
     * @return messageHash_ Message hash.
     */
    function _messageHash(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender,
        bytes32 _domainSeparator
    )
        internal
        pure
        returns (bytes32 messageHash_)
    {
        bytes32 typedMessageHash = keccak256(
            abi.encode(
                MESSAGE_TYPEHASH,
                _intentHash,
                _nonce,
                _gasPrice,
                _gasLimit,
                _sender
            )
        );

        messageHash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                _domainSeparator,
                typedMessageHash
            )
        );
    }
}
