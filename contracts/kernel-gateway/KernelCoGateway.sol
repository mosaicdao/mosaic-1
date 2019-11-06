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

contract KernelCoGateway is
    MasterCopyNonUpgradable, // Always keep this always at location 0
    MessageInbox,
    ConsensusModule1, // TODO: replace this with ConsensusModule
    KernelBase
{
    /* Events */

    event ConfirmedOpenKernelGateway(bytes32 kernelMessageHash);


    /* Constants */

    /** This is the storage index of MessageInbox::inbox mapping. */
    uint8 constant public INBOX_OFFSET = 1;


    /* External Functions */

    /**
     * @notice Setup kernel cogateway contract.
     * @param _chainId Chain identifier.
     * @param _kernelGateway KernelGateway contract address.
     * @param _outboxStorageIndex Storage index of outbox mapping in
     *                            KernelGateway contract.
     * @param _stateRootProvider State root provider contract address.
     * @param _maxStorageRootItems Defines how many storage roots should be
     *                             stored in circular buffer.
     */
    function setup(
        bytes20 _chainId,
        address _kernelGateway,
        uint8 _outboxStorageIndex,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        // Make sure that this function is called only once.
        require(
            chainId == bytes20(0),
            "KernelCoGateway is already setup."
        );

        require(
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _kernelGateway != address(0),
            "KernelGateway address is 0."
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

    /**
     *  @notice Verify merkle proof of a KernelGateway contract address.
     *          Trust factor is brought by state roots of the contract which
     *          implements StateRootInterface.
     *  @param _blockHeight Block height at which KernelGateway contract is to be
     *                      proven.
     *  @param _rlpAccount RLP encoded account node object.
     *  @param _rlpParentNodes RLP encoded value of account proof parent nodes.
     *  @return `true` if KernelGateway account is proved.
     */
    function proveKernelGateway(
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
     * @notice Confirm that a new kernel is opened by providing the merkel proof.
     * @param _height The height of meta-block.
     * @param _parent The hash of this block's parent.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock.
     * @param _gasPrice Gas price.
     * @param _gasLimit Gas limit.
     * @param _sender Sender address.
     * @param _blockHeight Block height for fetching storage root.
     * @param _rlpParentNodes RLP encoded parent node data to prove in
     *                        message outbox.
     */
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
