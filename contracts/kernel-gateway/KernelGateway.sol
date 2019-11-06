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

import "../message-bus/MessageOutbox.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../consensus/ConsensusModule1.sol";
import "./KernelBase.sol";

contract KernelGateway is
    MasterCopyNonUpgradable, // Always keep this always at location 0
    MessageOutbox,
    ConsensusModule1, // TODO: replace this with ConsensusModule
    KernelBase
{
    /* Events */

    event OpenedNewKernelGateway(bytes32 kernelMessageHash);


    /* Constants */

    /** This is the storage index of MessageOutbox::outbox mapping. */
    uint8 constant public OUTBOX_OFFSET = 1;


    /* External Functions */

    /**
     * @notice Setup kernel gateway contract.
     * @param _chainId Chain identifier.
     * @param _kernelCoGateway KernelCoGateway contract address.
     */
    function setup(
        bytes20 _chainId,
        address _kernelCoGateway
    )
        external
    {
        // Make sure that this function is called only once.
        require(
            chainId == bytes20(0),
            "Kernel gateway is already setup."
        );

        require(
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _kernelCoGateway != address(0),
            "KernelCoGateway address is 0."
        );

        chainId = _chainId;
        consensus = ConsensusI(msg.sender);

        // Setup message out box.
        MessageOutbox.setupMessageOutbox(
            _chainId,
            _kernelCoGateway
        );
    }

    /**
     * @notice Declare new kernel opening. Only consensus contract can call
     *         this function.
     * @param _height The height of meta-block.
     * @param _parent The hash of this block's parent.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock
     * @return Kernel message hash.
     */
    function openNewKernel(
        uint256 _height,
        bytes32 _parent,
        address[] calldata _updatedValidators,
        uint256[] calldata _updatedReputation,
        uint256 _gasTarget
    )
        onlyConsensus
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

        latestKernelHeight = _height;
        latestGasTarget = _gasTarget;

        /* @dev: Here the kernelHash is not used instead kernelIntentHash is
         *       used. For the kernelHash, the verifying contract used in
         *       domain separator is core address. This means that in the
         *       KernelCoGateway the core address needs to be provided at the
         *       setup. If the new core is created then the core address needs
         *       to be updated in KernelCoGateway or deploy a new set of kernel
         *       gateways.
         *       Kernel gateway is more related to message passing
         *       between the chains. The message bus itself has the logic
         *       related to domain separator and this function can only be
         *       called by consensus contract, so its safe to use the
         *       kernelType hash as an intent hash here.
         */
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
            "Open kernel already exists."
        );

        // Declare message in outbox.
        // TODO: Check with team for the gas price and gas limit values.
        kernelMessageHash_ = MessageOutbox.declareMessage(
            kernelIntentHash,
             nonce,
            0, // Gas price is 0
            0, // Gas limit is 0
            address(consensus)
        );

        // Increment the nonce
        nonce = nonce.add(1);

        // Store the kernel message hash.
        // TODO: Update the logic to delete the kernel message hash.
        kernelMessages[kernelIntentHash] = kernelMessageHash_;

        emit OpenedNewKernelGateway(kernelMessageHash_);
    }
}
