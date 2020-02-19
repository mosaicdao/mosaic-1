pragma solidity >=0.5.0 <0.6.0;

// Copyright 2020 OpenST Ltd.
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

import "./ERC20GatewayBase.sol";
import "../message-bus/MessageBus.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title ERC20Gateway Contract.
 *
 * @notice ERC20Gateway contract is used to move any ERC20 tokens between two
 *         chains.
 */
contract ERC20Gateway is MasterCopyNonUpgradable, MessageBus, ERC20GatewayBase {

    /* Constants */

    /** Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /** Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /* External Functions */

    /**
     * @notice Setup function for ERC20 gateway contract.
     *
     * @dev  Validations for input parameters are done in message outbox and
     *       message inbox setup method.
     *
     * @param _metachainId Metachain Id.
     * @param _erc20Cogateway Address of ERC20 Cogateway contract.
     * @param _stateRootProvider State root provider contract address.
     * @param _maxStorageRootItems Maximum number of storage roots stored.
     * @param _outboxStorageIndex Outbox storage index of ERC20 Cogateway.
     *
     * \pre  This function can only be called once. It's ensured by setup
     *       function of message outbox and inbox.
     *
     * \post Setup message outbox and updates outboundChannelIdentifier storage
     *       variable.
     * \post Setup message inbox and updates inboundChannelIdentifier storage
     *       variable.
     */
    function setup(
        bytes32 _metachainId,
        address _erc20Cogateway,
        StateRootInterface _stateRootProvider,
        uint256 _maxStorageRootItems,
        uint8 _outboxStorageIndex
    )
        external
    {
        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _erc20Cogateway
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _erc20Cogateway,
            _outboxStorageIndex,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }

    /**
     * @notice This method verifies merkle proof of ERC20 cogateway contract.
     *
     * @param _blockNumber Block number at which ERC20 cogateway contract
     *                     address is to be proven.
     * @param _rlpAccount RLP encoded account node object.
     * @param _rlpParentNodes RLP encoded value of account proof node array.
     *
     * \post Emits GatewayProven event on successful execution.
     * \post It calls MessageInbox.proveStorageAccount() with parameters
     *       blockNumber, rlpAccountNode, rlpParentNodes.
     */
    function proveGateway(
        uint256 _blockNumber,
        bytes calldata _rlpAccount,
        bytes calldata _rlpParentNodes
    )
        external
    {
        MessageInbox.proveStorageAccount(
            _blockNumber,
            _rlpAccount,
            _rlpParentNodes
        );

        emit GatewayProven(address(this), _blockNumber);
    }

}
