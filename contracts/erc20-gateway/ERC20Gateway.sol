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
import "../ERC20I.sol";
import "../message-bus/MessageBus.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title ERC20Gateway Contract.
 *
 * @notice ERC20Gateway contract is used to move any ERC20 tokens between two
 *         chains.
 */
contract ERC20Gateway is MasterCopyNonUpgradable, MessageBus, ERC20GatewayBase {

    /* Events */

    /** Emitted when deposit intent is declared. */
    event DepositIntentDeclared(
        uint256 amount,
        uint256 nonce,
        address beneficiary,
        uint256 feeGasPrice,
        uint256 feeGasLimit,
        address depositor,
        address valueToken,
        bytes32 messageHash
    );

    /** Emitted when withdraw intent is confirmed. */
    event WithdrawIntentConfirmed(bytes32 messageHash);


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
     * @notice This method verifies merkle proof of ERC20Cogateway contract.
     *
     * @param _blockNumber Block number at which ERC20Cogateway contract
     *                     address is to be proven.
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

    /**
     * @notice Deposit ERC20 token to mint utility token on the auxiliary chain.
     *
     * @param _amount Amount of token to be deposited in atto
     * @param _beneficiary Address of beneficiary on the auxiliary chain.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     * @param _valueToken Address of ERC20 token.
     *
     * @return messageHash_ Message hash.
     *
     * \pre  `msg.sender` should approve this contract for `_amount` number of
     *       token transfer.
     * \pre  `_valueToken` address must not be zero.
     * \pre  `_amount` should be greater than max reward. Max reward is
     *       calculated as `_feeGasPrice.mul(_feeGasLimit),`
     * \pre  `_beneficiary` address must not be zero.
     *
     * \post Adds a new entry in `outbox` mapping storage variable. The value is
     *       set as `true` for `messageHash_` in `outbox` mapping. The
     *       `messageHash_` is obtained by calling
     *       `MessageOutbox.declareMessage` with the parameters `depositIntentHash`,
     *      `MessageOutbox.outboxNonces[msg.sender]`,`_feeGasPrice`,
     *       `_feeGasLimit`,`msg.sender`. depositIntentHash is calculated by
     *       calling `ERC20GatewayBase.hashDepositIntent()` with `_valueToken`,
     *       `_amount` and `_beneficiary` as input parameters.
     * \post Updates the `MessageOutbox.outboxNonces` storage mapping variable
     *       by incrementing the value for `msg.sender` by one.
     * \post Transfers `_amount` of tokens from `msg.sender` to ERC20Gateway contract.
     * \post Emits `DepositIntentDeclared` event with the address of `messageHash_`,
     *       `_valueToken`, `msg.sender`, `_amount`, `nonce`, `_beneficiary`,
     *       `_feeGasPrice` and `_feeGasLimit` parameters.
     */
    function deposit(
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _valueToken
    )
        external
        returns (bytes32 messageHash_)
    {
        require(
            _valueToken != address(0),
            "Value token address is 0."
        );
        require(
            _amount != 0,
            "Deposit amount is 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address is 0."
        );
        require(
            _amount > _feeGasPrice.mul(_feeGasLimit),
            "Deposit amount should be greater than max reward."
        );

        bytes32 depositIntentHash = hashDepositIntent(
            _valueToken,
            _amount,
            _beneficiary
        );

        uint256 nonce = MessageOutbox.outboxNonces[msg.sender];
        MessageOutbox.outboxNonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageOutbox.declareMessage(
            depositIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );

        ERC20I(_valueToken).transferFrom(msg.sender, address(this), _amount);

        emit DepositIntentDeclared(
            _amount,
            nonce,
            _beneficiary,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender,
            _valueToken,
            messageHash_
        );
    }

    /**
     * @notice Confirm withdraw in order to transfer value token.
     *
     * @param _utilityToken Address of utility token contract.
     * @param _valueToken Address of value token contract.
     * @param _amount Value token amount for withdrawal.
     * @param _beneficiary Address of beneficiary where tokens will be withdrawn.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     *
     * @param _blockNumber Block number of auxiliary chain against which storage
                           proof is generated.
     * @param _withdrawer Address of the withdrawer account.
     * @param _rlpParentNodes Storage merkle proof to verify message declaration
                              on the origin chain.
     *
     * @return messageHash_ Message hash.
     *
     * \pre `_utilityToken` address is not 0.
     * \pre `_valueToken` address is not 0.
     * \pre `_amount` is not 0.
     * \pre `_beneficiary` address is not 0.
     * \pre `_withdrawer` address is not 0.
     * \pre `_rlpParentNodes` is not 0.
     *
     * \post Adds a new entry in `inbox` mapping storage variable. The value is
     *       set as `true` for `messagehash_` in `inbox` mapping. The
     *       `messageHash_` is calculated by `MessageInbox.confirmMessage`.
     * \post Transfers the tokens to the `msg.sender` address as a fees.
     *       The `fees` amount is calculated by calling
     *       `ERC20GatewayBase::reward()` with parameters `gasConsumed`,
     *       `_feeGasPrice` and `_feeGasLimit`. `gasConsumed` is the approximate
     *       gas used in this transaction.
     * \post Transfer the `_amount-fees` amount of token to the `_beneficiary`
     *       address.
     * \post Update the MessageInbox.inboxNonces storage mapping variable by
     *       incrementing the value for `_withdrawer` by one.
     * \post Emits `WithdrawIntentConfirmed` event with the `messageHash_` parameter.
     */
    function confirmWithdraw(
        address _utilityToken,
        address _valueToken,
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _withdrawer,
        uint256 _blockNumber,
        bytes calldata _rlpParentNodes
    )
        external
        returns (bytes32 messageHash_)
    {
        uint256 initialGas = gasleft();
        require(
            _utilityToken != address(0),
            "Utility Token address is 0."
        );
        require(
            _valueToken != address(0),
            "Value Token address is 0."
        );
        require(
            _amount != 0,
            "Withdraw amount is 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address is 0."
        );
        require(
            _withdrawer != address(0),
            "Withdrawer address is 0."
        );

        uint256 nonce = MessageInbox.inboxNonces[_withdrawer];
        MessageInbox.inboxNonces[_withdrawer] = nonce.add(1);

        messageHash_ = MessageInbox.confirmMessage(
            ERC20GatewayBase.hashWithdrawIntent(
                _valueToken,
                _utilityToken,
                _amount,
                _beneficiary
            ),
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            _withdrawer,
            _blockNumber,
            _rlpParentNodes
        );

        uint256 gasConsumed = initialGas.sub(gasleft());
        uint256 feeAmount = ERC20GatewayBase.reward(
            gasConsumed,
            _feeGasPrice,
            _feeGasLimit
        );
        uint256 withdrawAmount = _amount.sub(feeAmount);

        require(
            ERC20I(_valueToken).transfer(msg.sender, feeAmount),
            "Reward transfer must succeed."
        );
        require(
            ERC20I(_valueToken).transfer(_beneficiary, withdrawAmount),
            "Token transfer to the beneficiary must succeed."
        );

        emit WithdrawIntentConfirmed(messageHash_);
    }
}
