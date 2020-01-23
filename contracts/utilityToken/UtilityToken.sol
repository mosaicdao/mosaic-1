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

import "./ERC20Token.sol";

/**
 *  @title UtilityToken is an EIP20Token.
 *
 *  @notice This contract extends the functionalities of the EIP20Token.
 *
 */
contract UtilityToken is ERC20Token {
    /* events */

    /** Emitted whenever a ConsensusCogateway address is set */
    event ConsensusCogatewaySet(address _consensusCogateway);

    /* Storage */

    /** Address of ConsensusCogateway contract. */
    address public consensusCogateway;

    /* Modifiers */

    /** Checks that only ConsensusCogateway can call a particular function. */
    modifier onlyConsensusCogateway() {
        require(
            msg.sender == address(consensusCogateway),
            "Only ConsensusCogateway can call the function."
        );

        _;
    }
}
