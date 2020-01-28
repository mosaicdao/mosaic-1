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

import "./../../most/Utmost.sol";

/**
 * @title UtmostTest contract.
 */
contract UtmostTest is Utmost {

    /* Public functions. */

    /**
     * @notice Set the Utmost token balance for the given account address.
     *
     * @dev This is used only for testing.
     *
     * @param _account Address for which the balance is to be set.
     * @param _amount The amount of Utmost tokens to be set.
     */
    function setTokenBalance(
        address _account,
        uint256 _amount
    )
        external
    {
        balances[_account] = _amount;
    }

    /**
     * @notice Sets the base coin balance for the given account address.
     *
     * @dev This is used only for testing.
     * Returns true if successful.
     */
    function initializeBaseCoinBalance()
        external
        payable
        returns (bool success_)
    {
        success_ = true;
    }
}
