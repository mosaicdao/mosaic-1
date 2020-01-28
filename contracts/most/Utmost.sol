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

import "../proxies/MasterCopyNonUpgradable.sol";
import "./GenesisUtmost.sol";
import "../utilityToken/UtilityToken.sol";

/**
 * @title Utmost contract implements UtilityToken.
 *
 * @dev Utmost functions as the base coin to pay for gas consumption on the
 *      auxiliary chain.
 */
contract Utmost is MasterCopyNonUpgradable, GenesisUtmost, UtilityToken {

    /* Events */

    /** Emitted whenever the ERC20 Utmost is converted to base coin Utmost. */
    event TokenUnwrapped(
        address indexed _account,
        uint256 _amount
    );

    /** Emitted whenever the base coin Utmost is converted to ERC20 Utmost. */
    event TokenWrapped(
        address indexed _account,
        uint256 _amount
    );


    /** Constants */

    /** Token Symbol */
    string public constant TOKEN_SYMBOL = "UM";

    /** Token Name */
    string public constant TOKEN_NAME = "Utmost";

    /** Token Decimal */
    uint8 public constant TOKEN_DECIMALS = 18;


    /* External Functions */

    /**
     * @notice Sets up the _genesisTokenSupply and calls UtilityToken.setup.
     *
     * @dev This function must be called only once. This check is done in setup
     *      function of UtilityToken.
     *
     * @param _genesisTokenSupply Initial token supply.
     * @param _consensusCogateway ConsensusCogateway contract address.
     *
     */
    function setup(
        uint256 _genesisTokenSupply,
        address _consensusCogateway
    )
        external
    {
        UtilityToken.setup(
            TOKEN_SYMBOL,
            TOKEN_NAME,
            TOKEN_DECIMALS,
            _genesisTokenSupply,
            _consensusCogateway
        );

        genesisTotalSupply = _genesisTokenSupply;
    }

    /**
     * @notice Unwrap converts ERC20 Utmost to base coin.
     *
     * @dev  This contract's base coin balance must always be greater than
     *       unwrap amount.
     *
     * @param _amount Amount of ERC20 Utmost to convert to base coin.
     */
    function unwrap(
        uint256 _amount
    )
        external
        returns (bool success_)
    {
        require(
            _amount > 0,
            "Amount is zero."
        );

        require(
            _amount <= balances[msg.sender],
            "Insufficient balance."
        );

        assert(address(this).balance >= _amount);

        transferBalance(msg.sender, address(this), _amount);

        msg.sender.transfer(_amount);

        emit TokenUnwrapped(msg.sender, _amount);

        success_ = true;
    }

    /**
     * @notice Wrap converts base coin to ERC20 Utmost.
     *
     * @dev The ERC20 OST balance of contract should always be greater than the
     *      received payable amount.
     *
     * @return success_ `true` if wrap was successfully progressed.
     */
    function wrap()
        external
        payable
        returns (bool success_)
    {
        uint256 amount = msg.value;
        address account = msg.sender;

        require(
            amount > 0,
            "Payable amount should not be zero."
        );

        assert(balances[address(this)] >= amount);

        transferBalance(address(this), account, amount);

        emit TokenWrapped(account, amount);

        success_ = true;
    }

}
