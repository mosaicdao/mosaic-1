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
import "./StateRootInterface.sol";
import "./Proof.sol";

/**
 * @title MessageInbox - Contract to confirm the messages declared in MessageOutbox
 */
contract MessageInbox is MessageBox, Proof {

    // TODO: If we want to revert, may be the value will change to MessageBoxEnum.(still to think on this)
    /** Mapping to indicate that message hash exists in inbox. */
    mapping(bytes32 => bool) public inbox;

    /** Inbound channel identifier */
    bytes32 public inboundChannelIdentifier;

    /** Message outbox address */
    address public messageOutbox;

    /** Outbox storage index */
    uint8 public outboxStorageIndex;


    /* External Functions */

    /**
     * @notice Generate inbox message hash from the input params
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @param _sender Sender address.
     * @return messageHash_ Message hash.
     */
    function inboxMessageHash(
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
            inboundChannelIdentifier
        );
    }


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
    function setupMessageInbox(
        bytes32 _metachainId,
        address _messageOutbox,
        uint8 _outboxStorageIndex,
        StateRootInterface _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        internal
    {
        require(
            inboundChannelIdentifier == bytes32(0),
            "Message inbox is already setup."
        );

        require(
            _metachainId != bytes32(0),
            "metachain id is 0."
        );

        require(
            _messageOutbox != address(0),
            "Outbox address is 0."
        );

        require(
            address(_stateRootProvider) != address(0),
            "State root provider address is 0."
        );

        messageOutbox = _messageOutbox;
        outboxStorageIndex = _outboxStorageIndex;

        inboundChannelIdentifier = MessageBox.hashChannelIdentifier(
            _metachainId,
            messageOutbox,
            address(this)
        );


        /*
         * @dev: Please note that no validations are done here. Proof::setup
         *       already has the validations for the input params, so avoided
         *       the duplicate validations here.
         */
        Proof.setupProof(
            _messageOutbox,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }

    /**
     * @notice Verify merkle proof of a storage contract address.
     *         Trust factor is brought by state roots of the contract which
     *         implements StateRootInterface.
     * @param _blockHeight Block height at which Gateway/Cogateway is to be
     *                     proven.
     * @param _rlpAccount RLP encoded account node object.
     * @param _rlpParentNodes RLP encoded value of account proof parent nodes.
     */
    function proveStorageAccount(
        uint256 _blockHeight,
        bytes memory _rlpAccount,
        bytes memory _rlpParentNodes
    )
        internal
    {
        Proof.proveStorageAccount(
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
    function confirmMessage(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender,
        uint256 _blockHeight,
        bytes memory _rlpParentNodes
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
            inboundChannelIdentifier
        );

        require(
            inbox[messageHash_] == false,
            "Message already exists in the inbox."
        );

        inbox[messageHash_] = true;

        // Get the storage path to verify proof.
        bytes memory path = Proof.storagePath(
            outboxStorageIndex,
            messageHash_
        );

        Proof.proveStorageExistence(
            path,
            keccak256(abi.encodePacked(true)),
            _blockHeight,
            _rlpParentNodes
        );
    }
}
