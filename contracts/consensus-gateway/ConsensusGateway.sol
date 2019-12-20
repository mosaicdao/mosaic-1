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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../proxies/MasterCopyNonUpgradable.sol";
import "../message-bus/MessageBox.sol";
import "../message-bus/MessageBus.sol";
import "./ConsensusGatewayI.sol";
import "./ConsensusGatewayBase.sol";
import "../consensus/ConsensusModule.sol";
import "../core/CoreI.sol";

contract ConsensusGateway is MasterCopyNonUpgradable, MessageBus, ConsensusGatewayBase, ConsensusModule, ConsensusGatewayI {

    /* Usings */

    using SafeMath for uint256;


    /** Constants */

    /* Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /* Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /**
     * @notice Setup function for consensus gateway.
     *
     * @dev - Function can only be called once is ensured by setup function of
     *        message box.
     *      - Validations for input parameters are done in message box setup method.
     *
     * @param _metachainId Meta-chain Id
     * @param _most Address of most contract.
     * @param _consensus A consensus address.
     * @param _consensusCogateway Address of consensus cogateway contract.
     * @param _stateRootProvider Address of contract which implements
     *                           state-root provider interface.
     * @param _maxStorageRootItems Maximum number of storage roots stored.
     */
    function setup(
        bytes32 _metachainId,
        ERC20I _most,
        ConsensusI _consensus,
        address _consensusCogateway,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        ConsensusGatewayBase.setup(
            _most,
            uint256(0) // Current meta-block height
        );

        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _consensusCogateway,
            address(this)
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _consensusCogateway,
            OUTBOX_OFFSET,
            _stateRootProvider,
            _maxStorageRootItems,
            address(this)
        );

        setupConsensus(_consensus);
    }

    /**
     * @notice Function to declare open kernel in consensus gateway.
     *
     * @dev In case of chain halting when new Core is created, then new kernel
     *      can be opened at the same height.
     *      In normal cases, since this function is called by consensus, we can
     *      trust that same height will not be passed.
     *
     * @dev Function requires:
     *     - only consensus can call
     *     - Core address should not be 0
     *     - Kernel height should equal currentMetablockHeight plus one
     *     - New kernel can be opened at same height in case of chain halting
     *
     * @param _core Core contract address.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     * @return messageHash_ Message hash.
     */
    function declareOpenKernel(
        address _core,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        external
        onlyConsensus
        returns (bytes32 messageHash_)
    {
        require(
            _core != address(0),
            "Core address is 0."
        );

        (bytes32 openKernelHash, uint256 openKernelHeight) = CoreI(_core).getOpenKernel();
        require(
            openKernelHeight == currentMetablockHeight.add(1),
            "Kernel height should equal currentMetablockHeight plus one."
        );
        require(
            openKernelHeight == currentMetablockHeight,
            "New kernel can be opened at same height in case of chain halting."
        );

        currentMetablockHeight = openKernelHeight;

        bytes32 kernelIntentHash = hashKernelIntent(
            openKernelHeight,
            openKernelHash
        );

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

        bytes32 messageHash_ = MessageOutbox.declareMessage(
            kernelIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );
    }
}
