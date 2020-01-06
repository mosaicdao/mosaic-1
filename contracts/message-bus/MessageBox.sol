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

/**
 * @title MessageBox - Contains common code that will be used by MessageInbox and MessageOutbox
 */
contract MessageBox is MosaicVersion {

    /* Constants */

    /** EIP-712 domain separator name for Message bus */
    string public constant DOMAIN_SEPARATOR_NAME = "Message-Bus";

    /** EIP-712 domain separator for Message bus */
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,bytes32 metachainId,address verifyingContract)"
    );

    /** Message type hash */
    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(bytes32 intentHash,uint256 nonce,uint256 feeGasPrice,uint256 feeGasLimit,address sender)"
    );


    /* Internal functions */

    /**
     * @notice Generate message hash from the input params
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     * @param _domainSeparator Domain separator
     * @return messageHash_ Message hash.
     */
    function messageHash(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
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
                _feeGasPrice,
                _feeGasLimit,
                _sender
            )
        );

        messageHash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x4d), // 0x4d is for M (Mosaic)
                _domainSeparator,
                typedMessageHash
            )
        );
    }
}
