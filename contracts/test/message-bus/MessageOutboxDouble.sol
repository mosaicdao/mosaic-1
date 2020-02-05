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

import "../../message-bus/MessageOutbox.sol";

/**
 * @title MessageOutboxDouble contract.
 *
 * @notice It is used for testing MessageOutbox contract.
 */
contract MessageOutboxDouble is MessageOutbox {

    /* External Functions */

    /**
     * @notice It is used to setup message outbox.
     *
     * @param _metachainId Metahchain Id.
     * @param _messageInbox Address of message inbox.
     */
    function setupMessageOutboxDouble(
        bytes32 _metachainId,
        address _messageInbox
    )
        external
    {
        MessageOutbox.setupMessageOutbox(_metachainId, _messageInbox);
    }

    /**
     * @notice It is used to declare message at outbox.
     *
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     *
     * @return messageHash_ Message hash
     */
    function declareMessageDouble(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender
    )
        external
        returns (bytes32 messageHash_)
    {
        messageHash_ = MessageOutbox.declareMessage(
            _intentHash,
            _nonce,
            _feeGasPrice,
            _feeGasLimit,
            _sender
        );
    }
}
