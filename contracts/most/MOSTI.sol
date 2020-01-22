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

import "../ERC20I.sol";

interface MOSTI {

    /**
     * Mints the given amount of token to beneficiary.
     *
     * @param _beneficiary Address of beneficiary where tokens are minted.
     * @param _amount Amount in wei.
     *
     * @return bool `true` if success else `false`.
     */
    function mint(
        address _beneficiary,
        uint256 _amount
    )
        external
        returns(bool);

    /**
     * Burns the given amount(in atto) by msg.sender.
     *
     * @param _amount Amount in atto.
     *
     * @return bool `true` if success else `false`.
     */
    function burn(uint256 _amount)
        external
        returns(bool);

    /**
     * Burns the given amount(in atto) of the given account.
     *
     * @param _account Address of account for which the tokens will be burned.
     * @param _amount Amount in atto.
     *
     * @return bool `true` if success else `false`.
     */
    function burnFrom(address _account, uint256 _amount)
        external
        returns(bool);

}
