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
import "./StateRootI.sol";
import "./Proof.sol";

contract MessageInbox is MessageBox, Proof{

    /** Mapping to indicate that message hash exists in inbox. */
    mapping(bytes32 => bool) public inbox;

    /** Domain separator for inbox */
    bytes32 public inboxDomainSeparator;

    /** Message outbox address */
    address public messageOutbox;

    /** Outbox storage index */
    uint8 outboxStorageIndex;


    function setupMessageInbox(
        bytes20 _chainId,
        address _messageOutbox,
        uint8 _outboxStorageIndex,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        internal
    {
        require(
            inboxDomainSeparator == bytes32(0),
            "Message inbox is already setup."
        );

        require(
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _messageOutbox != address(0),
            "Inbox address is 0."
        );

        messageOutbox = _messageOutbox;
        outboxStorageIndex = _outboxStorageIndex;

        bytes32 salt = keccak256(
            abi.encode(
                _messageOutbox,
                address(this)
            )
        );

        inboxDomainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                DOMAIN_SEPARATOR_NAME,
                DOMAIN_SEPARATOR_VERSION,
                _chainId,
                address(this),
                salt
            )
        );

        /* @dev: Please note that no validations are done here. Proof::setup
         *       already has the validations for the input params, so avoided
         *       the duplications here.
         */
        Proof.initialize(
            _messageOutbox,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }

    /**
     * @notice Generate message hash from the input params
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _gasPrice Gas price.
     * @param _gasLimit Gas limit.
     * @param _sender Sender address.
     * @return messageHash_ Message hash.
     */
    function inboxMessageHash(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender
    )
        external
        view
        returns (bytes32 messageHash_)
    {
        messageHash_ = _messageHash(
            _intentHash,
            _nonce,
            _gasPrice,
            _gasLimit,
            _sender,
            inboxDomainSeparator
        );
    }

    /**
     * @notice Confirm a new message that is declared in outbox on the source
     *         chain. Merkle proof will be performed to verify storage data.
     *         This will update the inbox value to `true` for the given message hash.
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _gasPrice Gas price.
     * @param _gasLimit Gas limit.
     * @param _sender Sender address.
     * @param _blockHeight Block height for fetching storage root.
     * @param _rlpParentNodes RLP encoded parent node data to prove in
     *                        messageBox outbox.
     * @return messageHash_ Message hash.
     */
    function confirmMessage(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender,
        uint256 _blockHeight,
        bytes memory _rlpParentNodes
    )
        internal
        returns (bytes32 messageHash_)
    {
        messageHash_ = _messageHash(
            _intentHash,
            _nonce,
            _gasPrice,
            _gasLimit,
            _sender,
            inboxDomainSeparator
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
