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
import "./ConsensusGatewayBase.sol";

contract ConsensusGateway is MasterCopyNonUpgradable, MessageBus, ConsensusGatewayBase {
    /* Usings */

    using SafeMath for uint256;

    /* Constants */

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
     * @param _consensusCogateway Address of consensus cogateway contract.
     * @param _stateRootProvider Address of contract which implements
     *                           state-root provider interface.
     * @param _maxStorageRootItems Maximum number of storage roots stored.
     */
    function setup(
        bytes32 _metachainId,
        ERC20I _most,
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
    }

    /**
     * @notice Deposit funds to mint on auxiliary chain. Depositor needs to
     *         approve this contract with the deposit amount.
     *
     * @param _amount MOST token deposit amount in wei.
     * @param _beneficiary Address of beneficiary on auxiliary chain.
     * @param _feeGasPrice Fee gas price at which rewards will be calculated.
     * @param _feeGasLimit Fee gas limit at which rewards will be calculated.
     *
     * @return messageHash_ Message hash.
     */
    function deposit(
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        external
        returns(bytes32 messageHash_)
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

        bytes32 depositIntentHash = hashDepositIntent(_amount, _beneficiary);

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender].add(1);

        messageHash_ = MessageOutbox.declareMessage(
            depositIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );

        require(
            ERC20I(most).transferFrom(msg.sender, address(this), _amount),
            "MOST transferFrom must succeed."
        );
    }
}
