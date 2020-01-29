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

import "./GenesisUtmost.sol";

import "../consensus/CoconsensusModule.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../utility-token/UtilityToken.sol";

/**
 * @title Utmost contract implements UtilityToken. Utmost is an ERC20 token
 *        wrapper for the base coin that is used to pay for gas consumption on
 *        the auxiliary chain.
 */
contract Utmost is MasterCopyNonUpgradable, GenesisUtmost, UtilityToken, CoconsensusModule {

    /* Constants */

    /** Token Symbol */
    string public constant TOKEN_SYMBOL = "UM";

    /** Token Name */
    string public constant TOKEN_NAME = "Utmost";

    /** Token Decimal */
    uint8 public constant TOKEN_DECIMALS = 18;

    /** Consensus cogateway address defined in genesis. */
    address public constant CONSENSUS_COGATEWAY = address(0x0000000000000000000000000000000000004d02);


    /* External Functions */

    /**
     * @notice Initializes the Utmost contract.
     *
     * @dev This function must be called only once. This check is done in setup
     *      function of UtilityToken.
     *
     *      Function requires:
     *          - msg.sender should be Coconsensus
     */
    function setup()
        external
        onlyCoconsensus
    {
        UtilityToken.setup(
            TOKEN_SYMBOL,
            TOKEN_NAME,
            TOKEN_DECIMALS,
            genesisTotalSupply,
            CONSENSUS_COGATEWAY
        );

        /*
         * In the genesis block, validators gets base token equivalent to the
         * amount they deposited before joining the core. Equivalent
         * amount of ERC20 token should be minted and Utmost contract should
         * hold that balance. Similar flow will happen in normal mint process
         * where Utmost contract ERC20 balance will be incremented. So in the
         * setup, Utmost contract holds the ERC20 token balance equal to the
         * genesisTotalSupply.
         */
        balances[address(this)] = genesisTotalSupply;
    }

    /**
     * @notice Unwrap converts ERC20 Utmost to base coin.
     *
     * @dev  This contract's base coin balance must always be greater than
     *       unwrap amount.
     *
     *       Function requires:
     *          - Amount should be non-zero
     *          - Caller Utmost token balance should be greater than amount
     *
     * @param _amount Amount of ERC20 Utmost token to convert to base coin.
     */
    function unwrap(
        uint256 _amount
    )
        external
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
    }

    /**
     * @notice Wrap converts base coin to ERC20 Utmost.
     *
     * @dev The ERC20 OST balance of contract should always be greater than the
     *      received payable amount.
     *
     *      Function requires:
     *          - msg.value should be non-zero
     */
    function wrap()
        external
        payable
    {
        uint256 amount = msg.value;
        address account = msg.sender;

        require(
            amount > 0,
            "Payable amount should not be zero."
        );

        assert(balances[address(this)] >= amount);

        transferBalance(address(this), account, amount);
    }

}
