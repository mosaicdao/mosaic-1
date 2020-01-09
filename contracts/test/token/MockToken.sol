pragma solidity >=0.5.0 <0.6.0;

// Copyright 2019 OpenST Ltd.
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
//
// ----------------------------------------------------------------------------
// Contracts: MockToken
//
// http://www.simpletoken.org/
//
// ----------------------------------------------------------------------------


import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../ERC20I.sol";


contract MockToken is ERC20 {

    using SafeMath for uint256;

    constructor(uint8 _decimals) public {
        uint256 decimalsFactor = 10**uint256(_decimals);
        uint256 tokensMax = 800000000 * decimalsFactor;
        _mint(msg.sender, tokensMax);
    }
}
