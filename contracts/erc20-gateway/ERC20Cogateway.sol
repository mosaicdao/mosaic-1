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
import "../proxies/ProxyFactory.sol";
import "../utility-token/UtilityTokenInterface.sol";

/**
 * @title ERC20Cogateway confirms the deposit intent and mint utility tokens.
 *        Also initiates the withdrawal of token.
 */
contract ERC20Cogateway is
    MasterCopyNonUpgradable,
    GenesisERC20Cogateway,
    MessageBus,
    ProxyFactory,
    ERC20GatewayBase {

    /* Events */

    /** Emitted when withdraw message is declared */
    event WithdrawIntentDeclared(
        uint256 amount,
        uint256 nonce,
        address beneficiary,
        uint256 feeGasPrice,
        uint256 feeGasLimit,
        address withdrawer,
        address utilityToken,
        bytes32 messageHash
    );

    /** Emitted when deposit message is confirmed. */
    event DepositIntentConfirmed(
        bytes32 messageHash
    );

    /** Emitted when utility token proxy is deployed. */
    event UtilityTokenCreated(
        address valueToken,
        address utilityToken
    );

    /* Constants */

    /** Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(6);

    /** Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(9);

    /** The callprefix of the UtilityToken::setup(). */
    bytes4 public constant UTILITY_TOKEN_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(string,string,uint8,uint256,address,address)"
        )
    );


    /* Storage */

    /** Address of Utility token contract master copy. */
    address public utilityTokenMasterCopy;

    /* Mapping for utility token addresses */
    mapping (address => address) public utilityTokens;


    /* Public Functions */

    /**
     * @notice It initializes ERC20Cogateway contract.
     *
     * \pre Setup function can be called only once.
     *
     * \post Calls `MessageOutbox.setupMessageOutbox()` with parameters
     *       `genesisMetachainId` and `genesisERC20Gateway`.
     * \post Calls `MessageInbox.setupMessageInbox` with parameters
     *       `genesisMetachainId`, `genesisERC20Gateway`,
     *       `genesisOutboxStorageIndex`, `genesisStateRootProvider` and
     *       `genesisOutboxStorageIndex`.
     * \post Sets `utilityTokenMasterCopy` storage variable with
     *       `genesisUtilityTokenMastercopy` value.
     */
    function setup()
        public
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
            genesisMaxStorageRootItems
        );

        utilityTokenMasterCopy = genesisUtilityTokenMastercopy;
    }


    /* External Functions */

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

    /**
     * @notice It allows withdrawing Utility tokens. Withdrawer needs to
     *       approve erc20 cogateway contract for the amount to be
     *       withdrawn.
     *
     * @param _amount Amount of tokens to be withdrawn.
     * @param _beneficiary The address in the origin chain where the value
     *                     where the tokens will be withdrawn.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     * @param _utilityToken Address of utility token.
     *
     * @return messageHash_ Message hash.
     *
     * \pre `_utilityToken` is not 0.
     * \pre `_amount` is not 0.
     * \pre `_beneficiary` is not 0.
     * \pre `_amount` should be greater than maximum reward.
     * \pre `msg.sender` should approve erc20 cogateway contract.
     *
     * \post Adds a new entry in `outbox` mapping storage variable. The value is
     *       set as `true` for `messagehash_` in `outbox` mapping. The
     *       `messageHash_` is obtained by calling `MessageOutbox.declareMessage`
     *       with the parameters `withdrawIntentHash`,
     *       `MessageOutbox.outboxNonces[msg.sender]`, `_feeGasPrice`,
     *       `_feeGasLimit` and `msg.sender`. `withdrawIntentHash` is calculated
     *       by calling `ERC20GatewayBase.hashWithdrawIntent` with parameters
     *       `valueToken`, `_utilityToken`, `_amount`, `_beneficiary`.
     * \post `_amount` number of utility tokens will be burned from `msg.sender`
     *       account by erc20 cogateway.
     * \post Update the `MessageOutbox.outboxNonces` storage mapping variable
     *       by incrementing the value for `msg.sender` by one.
     * \post Emits `WithdrawIntentDeclared` event with the `_amount`, address of
     *       `_beneficiary`, `_feeGasPrice`, `_feeGasLimit`, address of
     *       `msg.sender`, address of `_utilityToken` and `messageHash_`.
     */
    function withdraw(
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        UtilityTokenInterface _utilityToken
    )
        external
        returns(bytes32 messageHash_)
    {
        require(
            address(_utilityToken) != address(0),
            "Utility Token address must not be 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _amount > _feeGasPrice.mul(_feeGasLimit),
            "Withdrawal amount should be greater than max reward."
        );

        address valueToken = _utilityToken.valueToken();
        bytes32 withdrawIntentHash = ERC20GatewayBase.hashWithdrawIntent(
            valueToken,
            address(_utilityToken),
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

        _utilityToken.burnFrom(msg.sender, _amount);

        emit WithdrawIntentDeclared(
            _amount,
            nonce,
            _beneficiary,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender,
            address(_utilityToken),
            messageHash_
        );
    }

    /**
     * @notice Confirm deposit in order to mint tokens.
     *
     * @param _valueToken ERC20 token address on the origin chain.
     * @param _amount ERC20 token deposit amount in atto.
     * @param _beneficiary Address of beneficiary on the target chain.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     * @param _depositor Address of depositor on the origin chain.
     * @param _blockNumber Block number of origin chain against which storage
                           proof is generated.
     * @param _rlpParentNodes Storage merkle proof to verify message declaration
     *                        on the origin chain.
     *
     * @return messageHash_ Message hash.
     *
     * \pre `_valueToken` address is not 0.
     * \pre `_amount` is not 0.
     * \pre `_beneficiary` address is not 0.
     * \pre `_depositor` address is not 0.
     * \pre `_rlpParentNodes` is not 0.
     *
     * \post Adds a new entry in `inbox` mapping storage variable. The value is
     *       set as `true` for `messagehash_` in `inbox` mapping. The
     *       `messageHash_` is calculated by calling `MessageInbox.confirmMessage`
     *       function with parameters `depositIntentHash`, `nonce`,
     *       `_feeGasPrice`, `_feeGasLimit`, `_depositor`, `_blockNumber` and
     *       `_rlpParentNodes`. `depositIntentHash` is calculated by calling
     *       `ERC20GatewayBase.hashDepositIntent` functions with the parameters
     *       `_valueToken`, `_amount` and `_beneficiary`.
     * \post Deploys a new utility token contract by calling
     *       `deployUtilityToken()` with parameter `_valueToken`.
     * \post Transfers the tokens to the `msg.sender` address as a fees.
     *       The `fees` amount is calculated by calling
     *       `ERC20GatewayBase::reward()` with parameters `gasConsumed`,
     *       `_feeGasPrice` and `_feeGasLimit`. `gasConsumed` is the approximate
     *       gas used in this transaction.
     * \post Transfer the `_amount-fees` amount of token to the `_beneficiary`
     *       address.
     * \post Update the MessageInbox.inboxNonces storage mapping variable by
     *       incrementing the
     *       value for `_withdrawer` by one.
     * \post Emits `DepositIntentConfirmed` event with the `messageHash_` as a
     *       parameter.
     */
    function confirmDeposit(
        address _valueToken,
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
            _valueToken != address(0),
            "Value token address must not be 0."
        );
        require(
            _amount != 0,
            "Deposit amount must not be 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _depositor != address(0),
            "Depositor address must not be 0."
        );

        address utilityToken = getUtilityToken(_valueToken);

        uint256 nonce = MessageInbox.inboxNonces[_depositor];
        MessageInbox.inboxNonces[_depositor] = nonce.add(1);

        messageHash_ = MessageInbox.confirmMessage(
            ERC20GatewayBase.hashDepositIntent(
                _valueToken,
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

        /*
         * Calculate the reward fees based on the actual gas usage. The value
         * of gas price can be adjusted to accommodate the additional gas usage
         * after this statement.
         */
        uint256 feeAmount = ERC20GatewayBase.reward(
            initialGas.sub(gasleft()),
            _feeGasPrice,
            _feeGasLimit
        );

        uint256 mintAmount = _amount.sub(feeAmount);

        UtilityTokenInterface(utilityToken).mint(msg.sender, feeAmount);

        UtilityTokenInterface(utilityToken).mint(_beneficiary, mintAmount);

        emit DepositIntentConfirmed(messageHash_);
    }


    /* Private Functions */

    /**
     * @notice Returns the utility token proxy contract.
     *
     * @param _valueToken Value token contract address.
     *
     * @return utilityToken_ Utility token contract address.
     *
     * \post Deploys a new proxy contract for utility token, if utility token
     *       address does not exists in `utilityTokens` mapping storage for the
     *       `_valueToken` key .
     * \post Updates the `utilityTokens` mapping storage by setting the values
     *       as address of newly deployed contract for `_valueToken` key.
     * \post Emits `UtilityTokenCreated` event with the `_valueToken`and
     *       `utilityToken_` as parameters.
     */
    function getUtilityToken(
        address _valueToken
    )
        private
        returns (address utilityToken_)
    {
        utilityToken_ = utilityTokens[_valueToken];

        if(utilityToken_ == address(0)) {
            bytes memory utilityTokenSetupCalldata = abi.encodeWithSelector(
                UTILITY_TOKEN_SETUP_CALLPREFIX,
                "",
                "",
                uint8(0),
                uint256(0),
                address(this),
                _valueToken
            );

            utilityToken_ = address(
                createProxy(
                    utilityTokenMasterCopy,
                    utilityTokenSetupCalldata
                )
            );

            utilityTokens[_valueToken] = utilityToken_;

            emit UtilityTokenCreated(
                _valueToken,
                utilityToken_
            );
        }
    }
}
