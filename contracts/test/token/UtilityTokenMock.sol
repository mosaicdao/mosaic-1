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

import "./ERC20Mock.sol";

/**
 * @title It is used for mocking utility token contract when testing other contracts.
 */
contract UtilityTokenMock is ERC20Mock {

    /** Address of valuetoken */
    address public valueToken;

    /* Special Functions */

    /**
     * @notice ERC20Mock constructor.
     *
     * @param _initialAccount Initial account for which tokens will be minted.
     * @param _initialBalance Initial token supply.
     */
    constructor(address _valueToken, address _initialAccount, uint256 _initialBalance)
        public
        ERC20Mock(_initialAccount, _initialBalance)
    {
        valueToken = _valueToken;
    }
}
