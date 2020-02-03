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
 * @title Utility token interface - It is an interface providing methods to
 *        burn the tokens.
 */
contract UtilityTokenInterface {

    /* External functions */

    /**
     * @notice Burns an amount of the token of a given
     *         account.
     * @param _account The account whose tokens will be burnt.
     * @param _value The amount that will be burnt.
     *
     * @return success_ `true` for a successful burn, `false` otherwise.
     */
    function burn(address _account, uint256 _value)
        external
        returns (bool success_);


    /**
     * @notice Burns an amount of the token of a given account, deducting
     *         from the sender's allowance for said account.
     * @param _account The account whose tokens will be burnt.
     * @param _value The amount that will be burnt.
     *
     * @return success_ `true` for a successful burnFrom, `false` otherwise.
     */
    function burnFrom(address _account, uint256 _value)
        external
        returns (bool success_);

}
