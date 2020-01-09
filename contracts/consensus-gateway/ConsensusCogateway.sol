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

import "../consensus/CoConsensusModule.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootI.sol";
import "../consensus-gateway/ConsensusGatewayBase.sol";
import "../consensus-gateway/ERC20GatewayBase.sol";
import "../consensus/CoConsensusI.sol";
import "../most/UTMOSTI.sol";

contract ConsensusCogateway is MasterCopyNonUpgradable, MessageBus, ConsensusGatewayBase, ERC20GatewayBase, CoConsensusModule {
    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /* Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /* Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /* External functions */

    /**
     * @notice It sets up consensus cogateway. It can only be called once.
     *
     * @param _metachainId Metachain id of a metablock.
     * @param _coConsensus Address of coConsensus contract.
     * @param _utMOST Address of most contract at auxiliary chain.
     * @param _consensusGateway Address of most contract at auxiliary chain.
     * @param _outboxStorageIndex Outbox Storage index of ConsensusGateway.
     * @param _maxStorageRootItems Max storage roots to be stored.
     * @param _metablockHeight Height of the metablock.
     */
    function setup(
        bytes32 _metachainId,
        address _coConsensus,
        ERC20I _utMOST,
        address _consensusGateway,
        uint8 _outboxStorageIndex,
        uint256 _maxStorageRootItems,
        uint256 _metablockHeight
    )
        external
    {
        /*
         * Setup method can only be called once because of the check for
         * outboundMessageIdentifier in setupMessageOutbox method of
         * MessageOutbox contract.
         */

        ConsensusGatewayBase.setup(_utMOST, _metablockHeight);

        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _consensusGateway
        );

        address anchor = CoConsensusI(_coConsensus).getAnchor(_metachainId);

        require(
            anchor != address(0),
            "Anchor address must not be 0."
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _consensusGateway,
            _outboxStorageIndex,
            StateRootI(anchor),
            _maxStorageRootItems
        );
    }

    /**
     * @notice Confirm deposit in order to mint tokens.
     *
     *
     * @param _amount MOST token deposit amount in atto.
     * @param _beneficiary Address of beneficiary on auxiliary chain.
     * @param _feeGasPrice Fee gas price at which rewards will be calculated.
     * @param _feeGasLimit Fee gas limit at which rewards will be calculated.
     * @param _depositor Address of depositor on the origin chain.
     * @param _blockHeight Block height of origin chain at which storage proof
     *                     is generated.
     * @param _rlpParentNodes Storage merkle proof to verify message declaration
     *                        on the origin chain.
     *
     * @return messageHash_ Message hash.
     */
    function confirmDeposit(
        uint256 _amount,
        address payable _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _depositor,
        uint256 _blockHeight,
        bytes calldata _rlpParentNodes
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
            _depositor != address(0),
            "Depositor address must not be 0."
        );

        uint256 initialGas = gasleft();

        bytes32 depositIntentHash = ERC20GatewayBase.hashDepositIntent(
            _amount,
            _beneficiary
        );

        messageHash_ = confirmMessage(
            _depositor,
            depositIntentHash,
            _feeGasPrice,
            _feeGasLimit,
            _blockHeight,
            _rlpParentNodes
        );

        uint256 gasConsumed = initialGas.sub(gasleft());
        uint256 rewardAmount = reward(gasConsumed, _feeGasPrice, _feeGasLimit);

        uint256 mintAmount = _amount.sub(rewardAmount);

        require(
            UTMOSTI(address(most)).mint(msg.sender, rewardAmount),
            "Reward must be minted"
        );

        require(
            UTMOSTI(address(most)).mint(_beneficiary, mintAmount),
            "Tokens must be minted for beneficiary"
        );
    }

    /**
     * @notice Calculates reward.
     *
     * @param _gasConsumed Gas consumption in confirm deposit transaction.
     * @param _feeGasPrice Fee gas price at which rewards will be calculated.
     * @param _feeGasLimit Fee gas limit at which rewards will be calculated.
     *
     * @return rewardAmount_ Total reward amount.
     */
    function reward(
        uint256 _gasConsumed,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        private
        pure
        returns(uint256 rewardAmount_)
    {
        if(_gasConsumed > _feeGasLimit) {
            rewardAmount_ = _feeGasPrice.mul(_feeGasLimit);
        } else {
            rewardAmount_ = _feeGasPrice.mul(_gasConsumed);
        }
    }

    /**
     * @notice Confirm message.
     *
     * @param _depositor Address of depositor.
     * @param _depositIntentHash Deposit intent hash.
     * @param _feeGasPrice Fee gas price at which rewards will be calculated.
     * @param _feeGasLimit Fee gas limit at which rewards will be calculated.
     * @param _blockHeight Block height of origin chain at which storage proof
     *                     is generated.
     * @param _rlpParentNodes Storage merkle proof to verify message declaration
     *                        on origin chain.
     *
     * @return rewardAmount_ Total reward amount.
     */
    function confirmMessage(
        address _depositor,
        bytes32 _depositIntentHash,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        uint256 _blockHeight,
        bytes memory _rlpParentNodes
    )
        private
        returns(bytes32 messageHash_)
    {
        uint256 nonce = nonces[_depositor];
        nonces[_depositor] = nonce.add(1);

        messageHash_ = MessageInbox.confirmMessage(
            _depositIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            _depositor,
            _blockHeight,
            _rlpParentNodes
        );
    }
}
