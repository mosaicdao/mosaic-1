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

import "../message-bus/StateRootI.sol";
import "../message-bus/MessageBusAdapter.sol";

contract KernelGateway is MessageBusAdapter {

    /**
     * @notice Constructor function sets address of message bus master copy contract.
     * @param _messageBusMasterCopy Message bus contract master copy address.
     */
    constructor(address _messageBusMasterCopy)
        public
        MessageBusAdapter(_messageBusMasterCopy)
    {

    }

    function setupGateway(
        address _coKernelGateway,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        MessageBusAdapter.setupMessageBus(
            _coKernelGateway,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }

    function openKernel(
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender
    )
        external
    {
        bytes32 openKernelIntentHash = openKernelIntentHash();
        MessageBusAdapter.declareMessage(
            openKernelIntentHash,
            _nonce,
            _gasPrice,
            _gasLimit,
            _sender
        );
    }

    function confirmOpenKernel(
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _sender,
        uint256 _blockHeight,
        bytes calldata _rlpParentNodes
    )
        external
    {
        bytes32 openKernelIntentHash = openKernelIntentHash();
        MessageBusAdapter.confirmMessage(
            openKernelIntentHash,
            _nonce,
            _gasPrice,
            _gasLimit,
            _sender,
            _blockHeight,
            _rlpParentNodes
        );
    }


    function openKernelIntentHash()
        internal
        pure
        returns (bytes32 kernelIntentHash_)
    {
        kernelIntentHash_ = keccak256('To be implemented');
    }
}
