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

import "./../../utility-token/UtilityToken.sol";

/**
 *  @title UtilityToken Test contract.
 */
contract UtilityTokenTest is UtilityToken {

    /* Public Functions */

    /**
     * @notice Sets up the symbol, name, decimals, totalSupply
     *         and the consensusCogateway address.
     *
     * @param _symbol Symbol of token.
     * @param _name Name of token.
     * @param _decimals Decimal of token.
     * @param _totalTokenSupply Total token supply.
     * @param _consensusCogateway ConsensusCogateway contract address.
     */
    function setupToken(
        string calldata _symbol,
        string calldata _name,
        uint8 _decimals,
        uint256 _totalTokenSupply,
        address _consensusCogateway
    )
        external
    {
       UtilityToken.setup(
           _symbol,
           _name,
           _decimals,
           _totalTokenSupply,
           _consensusCogateway
       );
    }
}
