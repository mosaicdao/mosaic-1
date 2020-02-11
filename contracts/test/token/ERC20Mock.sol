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

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title Mock ERC20 token used for testing.
 */
contract ERC20Mock is ERC20 {

    /* Special Functions */

    constructor(address _initialAccount, uint256 _initialBalance) public {
        _mint(_initialAccount, _initialBalance);
    }


    /* External Functions */

    /**
     * @notice Burn tokens from given address.
     */
    function burnFrom(address account, uint256 value)
        external
        returns (bool success_)
    {
        ERC20._burnFrom(account, value);
        success_ = true;
    }
}
