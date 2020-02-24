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

    /** Events */

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


    /* Constants */

    /** The callprefix of the UtilityToken::setup(). */
    bytes4 public constant UTILITY_TOKEN_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(string,string,uint8,uint256,address,address)"
        )
    );


    /* Storage */

    /* Value token address. */
    address public valueToken;

    /* Mapping for utility token addresses */
    mapping (address => address) public utilityTokens;


    /* External Functions */

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
     * @param _utilityToken Address of utility token
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
     *       with the parameters `withdrawIntentHash`, `nonces[msg.sender]`,
     *       `_feeGasPrice`, `_feeGasLimit` and `msg.sender`. `withdrawIntentHash`
     *       is calculated by calling `ERC20GatewayBase.hashWithdrawIntent` with
     *       parameters `valueToken`, `_utilityToken`, `_amount`, `_beneficiary`.
     * \post `_amount` number of utility tokens will be burned from `msg.sender`
     *       account by erc20 cogateway.
     * \post Update the `nonces` storage mapping variable by incrementing the
     *       value for `msg.sender` by one.
     * \post Emits `WithdrawIntentDeclared` event with the `_amount`, address of
     *       `_beneficiary`, `_feeGasPrice`, `_feeGasLimit`, address of
     *       `msg.sender`, address of `_utilityToken` and `messageHash_`.
     */
    function withdraw(
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit,
        address _utilityToken
    )
        external
        returns(bytes32 messageHash_)
    {
        require(
            _utilityToken != address(0),
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

        bytes32 withdrawIntentHash = ERC20GatewayBase.hashWithdrawIntent(
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

        UtilityTokenInterface(_utilityToken).burnFrom(msg.sender, _amount);

        emit WithdrawIntentDeclared(
            _amount,
            nonce,
            _beneficiary,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender,
            _utilityToken,
            messageHash_
        );
    }

    /**
     * @notice Confirm deposit in order to mint tokens.
     *
     * @param _amount ERC20 token deposit amount in atto.
     * @param _beneficiary Address of beneficiary on target metachain.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     * @param _valueToken ERC20 token address.
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
        address _valueToken,
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

        deployUtilityToken(_valueToken);

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

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

        uint256 feeAmount = ERC20GatewayBase.reward(
            initialGas.sub(gasleft()),
            _feeGasPrice,
            _feeGasLimit
        );

        uint256 mintAmount = _amount.sub(feeAmount);

        UtilityTokenInterface(address(_valueToken)).mint(msg.sender, feeAmount);

        UtilityTokenInterface(address(_valueToken)).mint(_beneficiary, mintAmount);
    }

    function deployUtilityToken(address _valueToken) public {
        address utilityToken = utilityTokens[_valueToken];

        if(utilityToken == address(0)) {
            bytes memory utilityTokenSetupCalldata = abi.encodeWithSelector(
                UTILITY_TOKEN_SETUP_CALLPREFIX,
                "",
                "",
                uint8(0),
                uint256(0),
                address(this),
                _valueToken
            );

            Proxy utilityTokenProxy = createProxy(
                genesisUtilityTokenMastercopy,
                utilityTokenSetupCalldata
            );

            utilityTokens[_valueToken] = address(utilityTokenProxy);
        }
    }
}
