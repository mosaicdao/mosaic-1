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

import "./StateRootI.sol";
import "./MessageBusProxy.sol";

contract MessageBusAdapter is MessageBusProxy {

    bytes4 public constant SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(address,address,uint256)"
        )
    );

    bytes4 public constant DECLARE_MESSAGE_CALLPREFIX = bytes4(
        keccak256(
            "declareMessage(bytes32,uint256,uint256,uint256,address)"
        )
    );

    bytes4 public constant CONFIRM_MESSAGE_CALLPREFIX = bytes4(
        keccak256(
            "confirmMessage(bytes32,uint256,uint256,uint256,address,uint256,bytes)"
        )
    );


    /**
     * @notice Constructor function sets address of message bus master copy contract.
     * @param _messageBusMasterCopy Message bus contract master copy address.
     */
    constructor(address _messageBusMasterCopy)
        public
        MessageBusProxy(_messageBusMasterCopy)
    {

    }


    /**
     * @notice Setup the proof contract. This can be called only once.
     * @param _storageAccount Storage account that will be proved.
     * @param _stateRootProvider State root provider contract address.
     * @param _maxStorageRootItems Defines how many storage roots should be
     *                             stored in circular buffer.
     */
    function setupMessageBus(
        address _storageAccount,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        internal
    {
        executeDelegateCall(
            abi.encodeWithSelector(
                SETUP_CALLPREFIX,
                _storageAccount,
                _stateRootProvider,
                _maxStorageRootItems
            )
        );
    }

    /**
     * @notice Declare a new message. This will update the outbox value to
     *         `true` for the given message hash.
     * @param _intentHash Intent hash of message.
     * @param _nonce Nonce of sender.
     * @param _gasPrice Gas price.
     * @param _gasLimit Gas limit.
     * @param _sender Sender address.
     * @return messageHash_ Message hash
     */
    function declareMessage(
        bytes32 _intentHash,
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender
    )
        internal
        returns (bytes32 messageHash_)
    {
        messageHash_ = executeDelegateCall(
            abi.encodeWithSelector(
                DECLARE_MESSAGE_CALLPREFIX,
                _intentHash,
                _nonce,
                _gasPrice,
                _gasLimit,
                _sender
            )
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
        messageHash_ = executeDelegateCall(
            abi.encodeWithSelector(
                CONFIRM_MESSAGE_CALLPREFIX,
                _intentHash,
                _nonce,
                _gasPrice,
                _gasLimit,
                _sender,
                _blockHeight,
                _rlpParentNodes
            )
        );
    }
}
