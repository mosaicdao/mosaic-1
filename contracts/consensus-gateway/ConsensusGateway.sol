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

import "./ConsensusGatewayBase.sol";
import "./ConsensusGatewayInterface.sol";
import "../consensus/ConsensusInterface.sol";
import "../consensus/ConsensusModule.sol";
import "../core/CoreInterface.sol";
import "../erc20-gateway/ERC20GatewayBase.sol";
import "../message-bus/MessageBus.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../utility-token/UtilityTokenInterface.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ConsensusGateway is
    MasterCopyNonUpgradable,
    MessageBus,
    ConsensusGatewayBase,
    ERC20GatewayBase,
    ConsensusModule,
    ConsensusGatewayInterface
{

    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /* Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /* Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /* Storage */

    /* Utility token address. */
    address public utilityToken = address(0);


    /* External Functions */

    /**
     * @notice Setup function for consensus gateway.
     *
     * @dev - Function can only be called once is ensured by setup function of
     *        message box.
     *      - Validations for input parameters are done in message box setup method.
     *
     * @param _metachainId Metachain Id
     * @param _consensus Address of consensus contract.
     * @param _most Address of MOST contract.
     * @param _consensusCogateway Address of consensus cogateway contract.
     * @param _maxStorageRootItems Maximum number of storage roots stored.
     * @param _outboxStorageIndex Outbox storage index of consensus cogateway.
     */
    function setup(
        bytes32 _metachainId,
        ConsensusInterface _consensus,
        ERC20I _most,
        address _consensusCogateway,
        uint256 _maxStorageRootItems,
        uint8 _outboxStorageIndex
    )
        external
    {
        ConsensusModule.setupConsensus(
            _consensus
        );

        ConsensusGatewayBase.setup(
            _most,
            uint256(0) // Current meta-block height
        );

        address stateRootProvider = _consensus.getAnchor(_metachainId);

        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _consensusCogateway
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _consensusCogateway,
            _outboxStorageIndex,
            StateRootInterface(stateRootProvider),
            _maxStorageRootItems
        );
    }

    /**
     * @notice Deposit funds to mint on auxiliary chain. Depositor needs to
     *         approve this contract with the deposit amount.
     *
     * @param _amount MOST token deposit amount in atto.
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

        bytes32 depositIntentHash = hashDepositIntent(address(most), _amount, _beneficiary);

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
            ERC20I(most).transferFrom(msg.sender, address(this), _amount),
            "MOST transferFrom must succeed."
        );
    }

    /**
     * @notice Function to declare open kernel in consensus gateway.
     *
     * @dev In case of chain halting when new Core is created, then new kernel
     *      can be opened at the same height.
     *      In normal cases, since this function is called by consensus, we can
     *      trust that same height will not be passed.
     *
     *      Function requires:
     *          - Only consensus can call
     *          - Core address should not be 0
     *          - Either Kernel height should equal currentMetablockHeight plus
     *            one or kernel can be opened at same height in case of chain
     *            halting.
     *
     * @param _core Core contract address.
     * @param _feeGasPrice Fee gas price.
     * @param _feeGasLimit Fee gas limit.
     *
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
            address(_core) != address(0),
            "Core address is 0."
        );

        (bytes32 openKernelHash, uint256 openKernelHeight) = CoreInterface(_core).getOpenKernel();

        require(
            (openKernelHeight == currentMetablockHeight.add(1)) ||
            (openKernelHeight == currentMetablockHeight),
            "Kernel can be opened at same height or currentMetablockHeight+1."
        );

        currentMetablockHeight = openKernelHeight;

        bytes32 kernelIntentHash = hashKernelIntent(
            openKernelHeight,
            openKernelHash
        );

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageOutbox.declareMessage(
            kernelIntentHash,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );
    }

    /**
     * @notice Confirm withdraw in order to transfer most.
     *
     * @param _amount MOST token amount for withdrawal
     * @param _beneficiary Address of beneficiary where tokens will be withdrawn.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     * @param _blockNumber Block number of Aux chain against which storage
                           proof is generated.
     * @param _withdrawer Address of the withdrawer account.
     * @param _rlpParentNodes Storage merkle proof to verify message declaration
                              on the origin chain.
     *
     * @return messageHash_ Message Hash
     *
     * \pre `_amount` is not 0.
     * \pre `_beneficiary` address is not 0.
     * \pre `_withdrawer` address is not 0.
     * \pre `_rlpParentNodes` is not 0
     *
     * \post Adds a new entry in `inbox` mapping storage variable. The value is
     *       set as `true` for `messagehash_` in `inbox` mapping. The
     *       `messageHash_` is calculated by `MessageInbox.confirmMessage`.
     * \post Update the nonces storage mapping variable by incrementing the
     *       value for `msg.sender` by one.
     * \post Transfers the `most` token to the `msg.sender` address as a fees.
     *       The `fees` amount is calculated by `ERC20GatewayBase::reward()`
     * \post Transfer the `most` token to the `_beneficiary` address. The
     *       transfer amount calculated as `_amount-fees`
     */
    function confirmWithdraw(
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
            _amount != 0,
            "Withdraw amount should be greater than 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _withdrawer != address(0),
            "Withdrawer address must not be 0."
        );

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageInbox.confirmMessage(
            ERC20GatewayBase.hashWithdrawIntent(
                address(most),
                utilityToken,
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
            ERC20I(most).transfer(msg.sender, feeAmount),
            "Reward transfer must succeed."
        );
        require(
            ERC20I(most).transfer(_beneficiary, withdrawAmount),
            "Token transfer to the beneficiary must succeed."
        );
    }

    /**
     * @notice Gets the remote gateway latest proven block number.
     *
     * @return blockNumber_ Remote gateway latest proven block number.
     */
    function getRemoteGatewayLatestProvenBlockNumber()
        external
        view
        returns (uint256 blockNumber_)
    {
        blockNumber_ = CircularBufferUint.head();
    }
}
