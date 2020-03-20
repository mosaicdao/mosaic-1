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

import "./MessageBox.sol";

/**
 * @title MessageOutbox - Contract to declare messages on the origin chain.
 */
contract MessageOutbox is MessageBox {

    /* Variables */

    // TODO: If we want to revert, may be the value will change to MessageBoxEnum.(still to think on this)
    /** Mapping to indicate that message hash exists in outbox. */
    mapping(bytes32 => bool) public outbox;

    /** Outbound channel identifier */
    bytes32 public outboundChannelIdentifier;

    /** Message inbox address */
    address public messageInbox;

    /** Mapping of message sender and nonce. */
    mapping(address => uint256) public outboxNonces;


    /* External Functions. */

    /**
     * @notice Generate outbox message hash from the input params
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     * @return messageHash_ Message hash.
     */
    function outboxMessageHash(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender
    )
        external
        view
        returns (bytes32 messageHash_)
    {
        messageHash_ = MessageBox.hashMessage(
            _intentHash,
            _nonce,
            _feeGasPrice,
            _feeGasLimit,
            _sender,
            outboundChannelIdentifier
        );
    }


    /* Internal Functions */

    /**
     * @notice Setup message outbox.
     *
     * @param _metachainId Metachain identifier.
     * @param _messageInbox MessageInbox contract address.
     *
     * \pre The function can be called only once.
     * \pre `_metachainId` must not be zero.
     * \pre `_messageInbox` address must not be zero.
     *
     * \post Sets `messageInbox` storage variable with `_messageInbox`.
     * \post Sets `outboundChannelIdentifier` storage variable.
     *       `outboundChannelIdentifier` is calculated by
     *       MessageBox.hashChannelIdentifier method.
     */
    function setupMessageOutbox(
        bytes32 _metachainId,
        address _messageInbox
    )
        internal
    {
        require(
            outboundChannelIdentifier == bytes32(0),
            "Message outbox is already setup."
        );

        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _messageInbox != address(0),
            "Message inbox address is 0."
        );

        messageInbox = _messageInbox;

        outboundChannelIdentifier = MessageBox.hashChannelIdentifier(
            _metachainId,
            address(this),
            messageInbox
        );
    }

    /**
     * @notice Declare a new message. This will update the outbox value to
     *         `true` for the given message hash.
     *
     * @dev Function requires:
     *          - message should not exists in outbox
     *
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender account.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     * @return messageHash_ Message hash
     */
    function declareMessage(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender
    )
        internal
        returns (bytes32 messageHash_)
    {
        messageHash_ = MessageBox.hashMessage(
            _intentHash,
            _nonce,
            _feeGasPrice,
            _feeGasLimit,
            _sender,
            outboundChannelIdentifier
        );

        require(
            outbox[messageHash_] == false,
            "Message already exists in the outbox."
        );

        outbox[messageHash_] = true;
    }
}
