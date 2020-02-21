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
import "./GenesisERC20Cogateway.sol";
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootInterface.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../utility-token/UtilityTokenInterface.sol";

/**
 * @title ERC20Cogateway confirms the deposit intent and mint utility tokens.
 *        Also initiates the withdrawal of token.
 */
contract ERC20Cogateway is MasterCopyNonUpgradable, GenesisERC20Cogateway, ERC20GatewayBase, MessageBus {

    /** Events */

    /** Emitted when withdraw message is declared */
    event WithdrawIntentDeclared(
        address utilityToken,
        uint256 amount,
        uint256 nonce,
        address beneficiary,
        uint256 feeGasPrice,
        uint256 feeGasLimit,
        address withdrawer,
        bytes32 messageHash
    );


    /* Storage */

    /**
     * Specifies if the ERC20Cogateway is activated.
     * @dev This is set to true when the setup is called. This ensures that
     *      the functions revert if they are called before the setup is done.
     */
    bool public activated;

    /* Value token address. */
    address public valueToken;


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
     * \post Activates gateway by setting 'activated' storage variable to 'true'.
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
     * @notice It allows withdrawing Utility tokens. Withdrawer needs to
     *       approve erc20 cogateway contract for the amount to be
     *       withdrawn.
     *
     * @param _utilityToken Address of utility token
     * @param _amount Amount of tokens to be withdrawn.
     * @param _beneficiary The address in the origin chain where the value
     *                     where the tokens will be withdrawn.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     *
     * @return messageHash_ Message hash.
     *
     * \pre `_utilityToken` is not 0.
     * \pre `_amount` is not 0.
     * \pre `_beneficiary` is not 0.
     * \pre `_amount` should be greater than maximum reward.
     *
     * \post Update the nonces storage mapping variable by incrementing the
     *       value for `msg.sender` by one.
     * \post Adds a new entry in `outbox` mapping storage variable. The value is
     *       set as `true` for `messagehash_` in `outbox` mapping. The
     *       `messageHash_` is calculated by `MessageOutbox.declareMessage`.
     * \post Utility tokens will be burned from `msg.sender` account
     *       by erc20 cogateway.
     */
    function withdraw(
        address _utilityToken,
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        external
        isActive
        returns(bytes32 messageHash_)
    {
        require(
            _utilityToken != address(0),
            "Utility Token address must not be 0."
        );
        require(
            _amount != 0,
            "Withdrawal amount should be greater than 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _amount > _feeGasPrice.mul(_feeGasLimit),
            "Withdrawal amount should be greater than max reward."
        );

        bytes32 withdrawIntentHash = hashWithdrawIntent(
            valueToken,
            _utilityToken,
            _amount,
            _beneficiary
        );

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageOutbox.declareMessage(
            withdrawIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );

        emit WithdrawIntentDeclared(
            _utilityToken,
            _amount,
            nonce,
            _beneficiary,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender,
            messageHash_
        );

        UtilityTokenInterface(_utilityToken).burnFrom(msg.sender, _amount);
    }
}
