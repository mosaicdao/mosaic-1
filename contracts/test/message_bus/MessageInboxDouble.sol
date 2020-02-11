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

import "../../message-bus/MessageInbox.sol";

/**
 * @title MessageInbox - Message Inbox test contract.
 */
contract MessageInboxDouble is MessageInbox {

    /* External Functions */

    /**
     * @notice It is used to test MessageInbox::setupMessageInbox
     */
    function setupMessageInboxExternal(
        bytes32 _metachainId,
        address _messageOutbox,
        uint8 _outboxStorageIndex,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        MessageInbox.setupMessageInbox(
            _metachainId,
            _messageOutbox,
            _outboxStorageIndex,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }

    /**
     * @notice It is used to test MessageInbox::proveStorageAccount
     */
    function proveStorageAccountExternal(
        uint256 _blockHeight,
        bytes calldata _rlpAccount,
        bytes calldata _rlpParentNodes
    )
        external
    {
        MessageInbox.proveStorageAccount(
            _blockHeight,
            _rlpAccount,
            _rlpParentNodes
        );
    }

    /**
     * @notice It is used to test MessageInbox::confirmMessage
     */
    function confirmMessageExternal(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender,
        uint256 _blockHeight,
        bytes calldata _rlpParentNodes
    )
        external
        returns (bytes32 messageHash_)
    {
        messageHash_ = MessageInbox.confirmMessage(
            _intentHash,
            _nonce,
            _feeGasPrice,
            _feeGasLimit,
            _sender,
            _blockHeight,
            _rlpParentNodes
        );
    }

    /**
     * @notice It sets inbound channel identifier.
     *
     * @param _inboundChannelIdentifier Inbound channel identifier.
     */
    function setInboundChannelIdentifier(
        bytes32 _inboundChannelIdentifier
    )
        external
    {
        inboundChannelIdentifier = _inboundChannelIdentifier;
    }

    /**
     * @notice It sets Storage root.
     *
     * @param _blockHeight Block height at which Gateway/Cogateway is to be
     *                     proven.
     * @param _storageRoot Storage root.
     */
    function setStorageRoots(
        uint256 _blockHeight,
        bytes32 _storageRoot
    )
        external
    {
        storageRoots[_blockHeight] = _storageRoot;
    }

    /**
     * @notice It sets Outbox storage index.
     *
     * @param _outboxStorageIndex Storage index of outbox mapping in
     *                            MessageOutbox contract.
     */
    function setOutboxStorageIndex(
        uint8 _outboxStorageIndex
    )
        external
    {
        outboxStorageIndex = uint8(_outboxStorageIndex);
    }
}
