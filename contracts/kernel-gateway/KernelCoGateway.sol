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

import "../proxies/MasterCopyNonUpgradable.sol";
import "../message-bus/MessageInbox.sol";
import "../consensus/ConsensusModule1.sol";
import "./KernelBase.sol";

contract KernelCoGateway is MasterCopyNonUpgradable, MessageInbox, ConsensusModule1, KernelBase {


    /* Events */

    event ConfirmedOpenKernelGateway(bytes32 kernelMessageHash);


    /* External Functions */

    function setup(
        bytes20 _chainId,
        address _kernelGateway,
        uint8 _outboxStorageIndex,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        require(
            chainId == bytes20(0),
            "Kernel cogateway is already setup."
        );

        require(
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _kernelGateway != address(0),
            "KernelCoGateway address is 0."
        );

        chainId = _chainId;
        consensus = ConsensusI(msg.sender);

        // Setup message out box.
        MessageInbox.setupMessageInbox(
            _chainId,
            _kernelGateway,
            _outboxStorageIndex,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }

    function confirmOpenKernel(
        uint256 _height,
        bytes32 _parent,
        address[] calldata _updatedValidators,
        uint256[] calldata _updatedReputation,
        uint256 _gasTarget,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender,
        uint256 _blockHeight,
        bytes calldata _rlpParentNodes
    )
        external
        returns (bytes32 kernelMessageHash_)
    {
        require(
            _height > latestKernelHeight,
            "Last declared kernel height is greater than the provided height"
        );

        require(
            _gasTarget > latestGasTarget,
            "Last declared gas target is greater than the provided gas target"
        );

        require(
            _sender != address(0),
            "Sender address is 0."
        );

        latestKernelHeight = _height;
        latestGasTarget = _gasTarget;

        bytes32 kernelIntentHash = kernelTypeHash(
            _height,
            _parent,
            _updatedValidators,
            _updatedReputation,
            _gasTarget
        );

        // Check if the kernel is already open.
        require(
            kernelMessages[kernelIntentHash] == bytes32(0),
            "Kernel opening already confirmed."
        );

        // Confirm message in inbox.
        kernelMessageHash_ = MessageInbox.confirmMessage(
            kernelIntentHash,
            nonce,
            _gasPrice, // Gas price is 0
            _gasLimit, // Gas limit is 0
            _sender,
            _blockHeight,
            _rlpParentNodes
        );

        // Increment the nonce
        nonce = nonce.add(1);

        // Store the kernel message hash.
        // TODO: Update the logic to delete the kernel message hash.
        kernelMessages[kernelIntentHash] = kernelMessageHash_;

        emit ConfirmedOpenKernelGateway(kernelMessageHash_);

    }
}
