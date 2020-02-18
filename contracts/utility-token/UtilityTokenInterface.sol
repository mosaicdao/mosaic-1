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

/**
 * @title An interface for Utility token contract.
 */
interface UtilityTokenInterface {

    /* External Functions */

    /**
     * @notice Mints the given amount of token to beneficiary.
     *
     * @param _beneficiary Address of beneficiary where tokens are minted.
     * @param _amount Amount in atto.
     */
    function mint(
        address payable _beneficiary,
        uint256 _amount
    )
        external;

    /**
     * @notice Burns an amount of the token of a given account.
     *
     * @param _value The amount in atto that will be burnt.
     */
    function burn(
        uint256 _value
    )
        external;

    /**
     * Burns the given amount(in atto) of the given account.
     *
     * @param _account Address of account for which the tokens will be burned.
     * @param _amount Amount in atto.
     */
    function burnFrom(address _account, uint256 _amount)
        external;

}
