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
import "./MessageBase.sol";
import "./Proof.sol";

contract MessageBus is MessageBox, MessageBase, Proof {

    /* External Functions */

    /**
     * @notice Setup the proof contract. This can be called only once.
     * @param _storageAccount Storage account that will be proved.
     * @param _stateRootProvider State root provider contract address.
     * @param _maxStorageRootItems Defines how many storage roots should be
     *                             stored in circular buffer.
     */
    function setup(
        address _storageAccount,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        /* @dev: Please note that no validations are done here. Proof::setup
         *       already has the validations for the input params, so avoided
         *       the duplications here.
         */
        Proof.initialize(
            _storageAccount,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }


    /* Internal Functions */

    /**
     * @notice Declare a new message. This will update the outbox value to
     *         `true` for the given message hash.
     *
     * @return messageHash_ Message hash
     */
    function declareMessage(
        Message memory _message
    )
        internal
        returns (bytes32 messageHash_)
    {
        messageHash_ = MessageBase.messageHash(_message);
        require(
            outbox[messageHash_] == false,
            "Message already exists in the outbox."
        );

        outbox[messageHash_] = true;
    }

    /**
     * @notice Confirm a new message that is declared in outbox on the source
     *         chain. Merkle proof will be performed to verify storage data.
     *         This will update the inbox value to `true` for the given message hash.
     * @param _message Message object.
     * @param _blockHeight Block height for fetching storage root.
     * @param _rlpParentNodes RLP encoded parent node data to prove in
     *                        messageBox outbox.
     * @return messageHash_ Message hash.
     */
    function confirmMessage(
        Message memory _message,
        uint256 _blockHeight,
        bytes memory _rlpParentNodes
    )
        internal
        returns (bytes32 messageHash_)
    {
        messageHash_ = MessageBase.messageHash(_message);
        require(
            inbox[messageHash_] == false,
            "Message already exists in the inbox."
        );

        inbox[messageHash_] = true;

        // Get the storage path to verify proof.
        bytes memory path = Proof.storagePath(
            OUTBOX_OFFSET,
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
