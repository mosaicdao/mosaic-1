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


import "../consensus/CoconsensusInterface.sol";
import "../consensus/CoconsensusModule.sol";
import "../consensus-gateway/ConsensusGatewayBase.sol";
import "../erc20-gateway/ERC20GatewayBase.sol";
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootInterface.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../utility-token/UtilityTokenInterface.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ConsensusCogateway is MasterCopyNonUpgradable, MessageBus, ConsensusGatewayBase, ERC20GatewayBase, CoconsensusModule {

    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /* Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /* Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /* Storage */

    /* Value token address. */
    address public valueToken;

    /** Mapping of kernel height and kernel hash. */
    mapping(uint256 /* Kernel Height */ => bytes32 /* Kernel Hash */) public  kernelHashes;


    /* External functions */

    /**
     * @notice It sets up consensus cogateway. It can only be called once.
     *
     * @param _metachainId Metachain id of a metablock.
     * @param _coconsensus Address of Coconsensus contract.
     * @param _utBase Address of UtBase contract at auxiliary chain.
     * @param _consensusGateway Address of consensus cogateway contract at auxiliary chain.
     * @param _outboxStorageIndex Outbox Storage index of ConsensusGateway.
     * @param _maxStorageRootItems Max storage roots to be stored.
     * @param _metablockHeight Height of the metablock.
     */
    function setup(
        bytes32 _metachainId,
        address _coconsensus,
        ERC20I _utBase,
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

        ConsensusGatewayBase.setup(_utBase, _metablockHeight);

        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _consensusGateway
        );

        address anchor = CoconsensusInterface(_coconsensus).getAnchor(_metachainId);

        require(
            anchor != address(0),
            "Anchor address must not be 0."
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _consensusGateway,
            _outboxStorageIndex,
            StateRootInterface(anchor),
            _maxStorageRootItems
        );
    }

    /**
     * @notice Confirm deposit in order to mint tokens.
     *
     * @param _amount MOST token deposit amount in atto.
     * @param _beneficiary Address of beneficiary on target metachain.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     * @param _depositor Address of depositor on the origin chain.
     * @param _blockNumber Block number of origin chain against which storage
                           proof is generated.
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
        uint256 _blockNumber,
        bytes calldata _rlpParentNodes
    )
        external
        returns (bytes32 messageHash_)
    {

        uint256 initialGas = gasleft();

        require(
            _amount != 0,
            "Deposit amount should be greater than 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _depositor != address(0),
            "Depositor address must not be 0."
        );

        uint256 nonce = MessageInbox.inboxNonces[msg.sender];
        MessageInbox.inboxNonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageInbox.confirmMessage(
            ERC20GatewayBase.hashDepositIntent(
                valueToken,
                _amount,
                _beneficiary
            ),
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            _depositor,
            _blockNumber,
            _rlpParentNodes
        );

        // Additional gas consumption after this statement can be adjusted with
        // the gas price value.
        uint256 gasConsumed = initialGas.sub(gasleft());
        uint256 feeAmount = ERC20GatewayBase.reward(gasConsumed, _feeGasPrice, _feeGasLimit);

        uint256 mintAmount = _amount.sub(feeAmount);

        UtilityTokenInterface(address(most)).mint(msg.sender, feeAmount);

        UtilityTokenInterface(address(most)).mint(_beneficiary, mintAmount);
    }

    /**
     * @notice This method will be called by anyone to verify merkle proof of
     *          consensus gateway contract address.
     *
     *  @param _blockNumber Block number at which consensus gateway is to be proven.
     *  @param _rlpAccount RLP encoded account node object.
     *  @param _rlpParentNodes RLP encoded value of account proof node array.
     */
    function proveConsensusGateway(
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
    }

    /**
     * @notice Confirms the initiation of opening a kernel at auxiliary chain.
     *
     * @dev Function requires:
     *          - Sender address must not be 0.
     *          - Kernel hash must not be 0.
     *          - Difference between kernelheight and current metablock height
     *            must be 1.
     *
     * @param _kernelHeight Height of the kernel.
     * @param _kernelHash Hash of the kernel.
     * @param _feeGasPrice Gas price which the sender is willing to pay.
     * @param _feeGasLimit Gas limit which the sender is willing to pay.
     * @param _sender Sender address.
     * @param _blockNumber Block number at which proof is valid.
     * @param _rlpParentNodes RLP encoded parent node data to prove message
     *                        exists in outbox of ConsensusGateway.
     *
     * @return messageHash_ Message hash.
     */
    function confirmOpenKernel(
        uint256 _kernelHeight,
        bytes32 _kernelHash,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _sender,
        uint256 _blockNumber,
        bytes calldata _rlpParentNodes
    )
        external
        returns (bytes32 messageHash_)
    {
        require(
            _sender != address(0),
            "Sender address is 0."
        );
        require(
            _kernelHash != bytes32(0),
            "Kernel hash is 0."
        );
        require(
            _kernelHeight.sub(currentMetablockHeight) == 1,
            "Invalid kernel height."
        );

        currentMetablockHeight = _kernelHeight;

        uint256 nonce = MessageInbox.inboxNonces[_sender];
        MessageInbox.inboxNonces[_sender] = nonce.add(1);

        bytes32 kernelIntentHash = hashKernelIntent(
            _kernelHeight,
            _kernelHash
        );

        messageHash_ = MessageInbox.confirmMessage(
            kernelIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            _sender,
            _blockNumber,
            _rlpParentNodes
        );

        kernelHashes[_kernelHeight] = _kernelHash;
    }

    /**
     * @notice It allows withdrawing UtBase tokens. Withdrawer needs to
     *         approve consensus cogateway contract for the amount to
     *         be withdrawn.
     *
     * @dev Function requires :
     *          - Amount must not be 0.
     *          - Beneficiary must not be 0.
     *          - Withdrawal amount must be greater than multiplication of
     *            gas price and gas limit.
     * @param _amount Amount of tokens to be redeemed.
     * @param _beneficiary The address in the origin chain where the value
     *                     where the tokens will be withdrawn.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     *
     * @return messageHash_ Message hash.
     */
    function withdraw(
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
            address(most),
            _amount,
            _beneficiary
        );

        uint256 nonce = MessageOutbox.outboxNonces[msg.sender];
        MessageOutbox.outboxNonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageOutbox.declareMessage(
            withdrawIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );

        UtilityTokenInterface(address(most)).burnFrom(msg.sender, _amount);
    }
}
