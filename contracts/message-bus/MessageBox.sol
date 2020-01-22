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

    /** Channel type hash */
    bytes32 public constant MMB_CHANNEL_TYPEHASH = keccak256(
        "MosaicMessageBusChannel(address outbox, address inbox)"
    );

    /** EIP-712 domain separator typehash for Mosaic bus */
    bytes32 public constant MMB_DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "MosaicMessageBus(string name,string version,bytes32 metachainId,bytes32 channelSeparator)"
    );

    /** EIP-712 domain separator name for Mosaic bus */
    string public constant MMB_DOMAIN_SEPARATOR_NAME = "Mosaic-Bus";

    /** Domain separator version */
    string public constant MMB_DOMAIN_SEPARATOR_VERSION = "0";

    /** Message type hash */
    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(bytes32 intentHash,uint256 nonce,uint256 feeGasPrice,uint256 feeGasLimit,address sender)"
    );


    /* Public Functions */

    /**
     * @notice Generate channel identifier hash from the input params
     * @param _metachainId Metachain identifier.
     * @param _outbox Outbox address.
     * @param _inbox Inbox address.
     */
    function hashChannelIdentifier(
        bytes32 _metachainId,
        address _outbox,
        address _inbox
    )
        public
        pure
        returns (bytes32 channelIdentifier_)
    {
        bytes32 channelSeparator = keccak256(
            abi.encode(
                MMB_CHANNEL_TYPEHASH,
                _outbox,
                _inbox
            )
        );

        channelIdentifier_ = keccak256(
            abi.encode(
                    MMB_DOMAIN_SEPARATOR_TYPEHASH,
                    MMB_DOMAIN_SEPARATOR_NAME,
                    MMB_DOMAIN_SEPARATOR_VERSION,
                    _metachainId,
                    channelSeparator
                )
        );
    }


    /* Internal functions */

    /**
     * @notice Generate message hash from the input params
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     * @param _channelIdentifier Channel identifier.
     * @return messageHash_ Message hash.
     */
    function hashMessage(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender,
        bytes32 _channelIdentifier
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
                _channelIdentifier,
                typedMessageHash
            )
        );
    }
}
