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

import "./GenesisERC20Cogateway.sol";
import "./ERC20GatewayBase.sol";
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootInterface.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title ERC20Cogateway confirms the deposit intent and mint utility tokens.
 *        Also initiates the withdrawal of token.
 */
contract ERC20Cogateway is
    MasterCopyNonUpgradable,
    GenesisERC20Cogateway,
    MessageBus,
    ERC20GatewayBase {

    /* Storage */

    /**
     * Specifies if the ERC20Cogateway is activated.
     * @dev This is set to true when the setup is called. This ensures that
     *      the functions revert if they are called before the setup is done.
     */
    bool public activated;


    /* Modifiers */

    /** Checks that contract is active. */
    modifier isActive() {
        require(
            activated == true,
            "ERC20Cogateway is not activated."
        );
        _;
    }


    /* External Functions */

    /**
     * @notice It initializes ERC20Cogateway contract.
     *
     * \pre Gateway is not activated.
     *
     * \post Activates gateway by setting 'activated' storage variable
     *       to 'true'.
     * \post Calls `MessageOutbox.setupMessageOutbox` and
     *       `MessageInbox.setupMessageInbox` with genesis* values read
     *       from `GenesisERC20Cogateway` contract.
     */
    function setup()
        external
    {
        require(
            !activated,
            "Gateway has been already activated."
        );

        MessageOutbox.setupMessageOutbox(
            genesisMetachainId,
            genesisERC20Gateway
        );

        MessageInbox.setupMessageInbox(
            genesisMetachainId,
            genesisERC20Gateway,
            genesisOutboxStorageIndex,
            StateRootInterface(genesisStateRootProvider),
            genesisOutboxStorageIndex
        );

        activated = true;
    }

    /**
     * @notice It verifies that ERC20Gateway contract exists on origin chain
     *         using merkle account proof.
     *
     * @param _blockNumber Block number at which ERC20Gateway contract is to
     *                     be proven.
     * @param _rlpAccount RLP encoded account node object.
     * @param _rlpParentNodes RLP encoded value of account proof node array.
     *
     * \post Calls `MessageInbox.proveStorageAccount()` function with
     *       `_blockNumber`, `_rlpAccount`, `_rlpParentNodes` as input
     *       parameters.
     * \post Emits `GatewayProven` event with the address of `messageInbox`
     *       and `_blockNumber` parameters.
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

        emit GatewayProven(messageInbox, _blockNumber);
    }
}
