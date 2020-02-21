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

    /* Emitted when deposit intent hash is declared. */
    event DepositIntentDeclared(
        bytes32 messageHash,
        address valueToken,
        uint256 amount,
        uint256 nonce,
        address beneficiary,
        uint256 feeGasPrice,
        uint256 feeGasLimit,
        address depositor
    );


    /* Constants */

    /** Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(6);

    /** Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(9);


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
     *       `_blockNumber`, `_rlpAccountNode`, `_rlpParentNodes` as input
     *       parameters.
     * \post Emits `GatewayProven` event with parameters `address(this)` and
     *       `_blockNumber`.
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
     * @notice Deposit funds to mint on auxiliary chain. Depositor needs to
     *         approve this contract with the deposit amount.
     *
     * @param _valueToken Address of value token.
     * @param _amount Value token token deposit amount in atto.
     * @param _beneficiary Address of beneficiary on auxiliary chain.
     * @param _feeGasPrice Fee gas price at which rewards will be calculated.
     * @param _feeGasLimit Fee gas limit at which rewards will be calculated.
     */
    function deposit(
        address _valueToken,
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        external
        returns (bytes32 messageHash_)
    {
        require(
            _amount != 0,
            "Deposit amount should be greater than 0"
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _amount > _feeGasPrice.mul(_feeGasLimit),
            "Deposit amount should be greater than max reward."
        );

        bytes32 depositIntentHash = hashDepositIntent(_valueToken, _amount, _beneficiary);

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageOutbox.declareMessage(
            depositIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );

        require(
            ERC20I(_valueToken).transferFrom(msg.sender, address(this), _amount),
            "Value token transferFrom must succeed."
        );

        emit DepositIntentDeclared(
            messageHash_,
            _valueToken,
            _amount,
            nonce,
            _beneficiary,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );
    }
}
