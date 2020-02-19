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
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootInterface.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title ERC20Cogateway confirms the deposit intent and mint utility tokens.
 *        Also initiates the withdrawal of token.
 */
contract ERC20Cogateway is MasterCopyNonUpgradable, GenesisERC20Cogateway, MessageBus {

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
     * \post Activates ERC20Cogateway contract by setting 'activated' storage
     *       variable 'true'.
     * \post It calls `MessageOutbox.setupMessageOutbox` and
     *       MessageInbox.setupMessageInbox.
     */
    function setup()
        external
    {
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
}
