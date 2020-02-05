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

import "../../message-Bus/MessageInbox.sol";

/**
 * @title MessageInbox - Contract to confirm the messages declared in MessageOutbox
 */

contract MessageInboxDouble is MessageInbox {
    /* Internal Functions */

    /**
     * @notice Setup message inbox.
     *
     * @dev Function requires:
     *          - inboundChannelIdentifier must be zero
     *          - metachainId must not be zero
     *          - messageOutbox address must not be zero
     *          - verifyingAddress must not be zero
     *          - stateRootProvider must not be zero
     *
     * @param _metachainId Metachain identifier.
     * @param _messageOutbox MessageOutbox contract address.
     * @param _outboxStorageIndex Storage index of outbox mapping in
     *                            MessageOutbox contract.
     * @param _stateRootProvider State root provider contract address.
     * @param _maxStorageRootItems Defines how many storage roots should be
     *                             stored in circular buffer.
     */

    function setupMessageInboxDouble(
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
     * @notice Verify merkle proof of a storage contract address.
     *         Trust factor is brought by state roots of the contract which
     *         implements StateRootInterface.
     * @param _blockHeight Block height at which Gateway/CoGateway is to be
     *                     proven.
     * @param _rlpAccount RLP encoded account node object.
     * @param _rlpParentNodes RLP encoded value of account proof parent nodes.
     */
    function proveStorageAccountDouble(
        uint256 _blockHeight,
        bytes calldata _rlpAccount,
        bytes calldata _rlpParentNodes
    )
        external
    {
        proveStorageAccount(
            _blockHeight,
            _rlpAccount,
            _rlpParentNodes
        );
    }

    /**
     * @notice Confirm a new message that is declared in outbox on the source
     *         chain. Merkle proof will be performed to verify storage data.
     *         This will update the inbox value to `true` for the given message hash.
     *
     * @dev  Function requires:
     *          - message should not exists in inbox
     *
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     * @param _blockHeight Block height for fetching storage root.
     * @param _rlpParentNodes RLP encoded parent node data to prove in
     *                        messageBox outbox.
     * @return messageHash_ Message hash.
     */
    function confirmMessageDouble(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender,
        uint256 _blockHeight,
        bytes calldata _rlpParentNodes
    )
        external
        returns (bytes32)
    {
        return confirmMessage(
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
     * @param _inboundChannelIdentifier Inboundchannel identifier.
     */
    function setInboundChannelIdentifier(
        bytes32 _inboundChannelIdentifier
    )
        public
    {
        inboundChannelIdentifier = _inboundChannelIdentifier;
    }

    /**
     * @notice It sets Storage Root.
     *
     * @param _blockHeight Block height at which Gateway/CoGateway is to be
     *                     proven.
     * @param _storageRoot Storage Root.
     */
    function setStorageRoots(
        uint256 _blockHeight,
        bytes32 _storageRoot
    )
        public
    {
        storageRoots[_blockHeight] = _storageRoot;
    }

    /**
     * @notice It sets Storage Root.
     *
     * @param _outboxStorageIndex Storage index of outbox mapping in
     *                            MessageOutbox contract.
     */
    function setOutboxStorageIndex(
        uint8 _outboxStorageIndex
    )
        public
    {
        outboxStorageIndex = uint8(_outboxStorageIndex);
    }
}