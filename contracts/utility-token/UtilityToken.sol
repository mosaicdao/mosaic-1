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

import "./ERC20Token.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 *  @title UtilityToken is an ERC20Token.
 *
 *  @notice This contract extends the functionalities of the ERC20Token.
 *
 */
contract UtilityToken is MasterCopyNonUpgradable, ERC20Token {

    /* Storage */

    /** Address of ConsensusCogateway contract. */
    address public consensusCogateway;

    /** Address of value token contract. */
    address public valueToken;


    /* Modifiers */

    /** Checks that only ConsensusCogateway can call a particular function. */
    modifier onlyConsensusCogateway() {
        require(
            msg.sender == address(consensusCogateway),
            "Only ConsensusCogateway can call the function."
        );

        _;
    }


    /* External Functions */

    /**
     * @notice Sets up the symbol, name, decimals, totalSupply, value token
     *         and the consensusCogateway address.
     *
     * @param _symbol Symbol of token.
     * @param _name Name of token.
     * @param _decimals Decimal of token.
     * @param _totalTokenSupply Total token supply.
     * @param _consensusCogateway ConsensusCogateway contract address.
     * @param _valueToken Address of value token contract.
     *
     * \pre Setup function can be called only once.
     * \pre `_consensusCogateway` address is not zero.
     * \pre `_valueToken` address is not zero.
     *
     * \post Sets `tokenSymbol` storage variable with `_symbol`.
     * \post Sets `tokenName` storage variable with `_name`.
     * \post Sets `tokenDecimals` storage variable with `_decimal`.
     * \post Sets the `totalTokenSupply` storage variable with
     *       `_totalTokenSupply`.
     * \post Sets the `consensusCogateway` storage variable with
     *       `_consensusCogateway`.
     * \post Sets the `valueToken` storage variable with `_valueToken`.
     */
    function setup(
        string calldata _symbol,
        string calldata _name,
        uint8 _decimals,
        uint256 _totalTokenSupply,
        address _consensusCogateway,
        address _valueToken
    )
        external
    {
        require(
            consensusCogateway == address(0),
            "Contract has been already setup."
        );

        require(
            _consensusCogateway != address(0),
            "ConsensusCogateway address should not be zero."
        );

        require(
            _valueToken != address(0),
            "Value token address must not be zero."
        );

        tokenSymbol = _symbol;
        tokenName = _name;
        tokenDecimals = _decimals;
        totalTokenSupply = _totalTokenSupply;
        consensusCogateway = _consensusCogateway;
        valueToken = _valueToken;
    }

    /**
     * @notice External function to mint tokens.
     *
     * @dev Mints an amount of the token and assigns it to an account.
     *      This encapsulates the modification of balances such that the
     *      proper events are emitted.
     * @param _account The account that will receive the created tokens.
     * @param _value The amount that will be created.
     */
    function mint(address _account, uint256 _value)
        external
        onlyConsensusCogateway()
    {
        _mint(_account, _value);
    }

    /**
     * @notice External function to burn tokens.
     *
     * @dev Burns an amount of utility token from caller of the method.
     *
     * @param _value The amount that will be burnt.
     */
    function burn(uint256 _value)
        external
    {
        _burn(msg.sender, _value);
    }

    /**
     * @notice External function to burn tokens of spender.
     *
     * @dev Burns an amount of the token of a given
     *      account, deducting from the sender's allowance for said
     *      account. Uses the internal _burnFrom function.
     * @param _account The account whose tokens will be burnt.
     * @param _value The amount that will be burnt.
     */
    function burnFrom(address _account, uint256 _value)
        external
    {
        _burnFrom(_account, _value);
    }
}
