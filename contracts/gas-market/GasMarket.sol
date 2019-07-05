pragma solidity ^0.5.0;

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

import "../utility-token/contracts/UtilityToken.sol";
import "../utility-token/contracts/organization/contracts/OrganizationInterface.sol";

contract GasMarket is UtilityToken {

    /* Storage */

    /** Address of OST on mainnet */
    address public constant OST_TOKEN_MAINNET = address(0x2C4e8f2D746113d0696cE89B35F0d8bF88E0AEcA);

    /** Symbol of OST, note the symbol is "ST" on mainnet contract */
    string public constant OST_TOKEN_SYMBOL = "OST";

    /** Name of OST */
    string public constant OST_TOKEN_NAME = "Simple Token";

    /** Decimals of OST */
    uint8 public constant OST_TOKEN_DECIMALS = 18;

    /** Kernel gateway contract address */
    address public kernelGateway;

    modifier onlyKernelGateway()
    {
        require(msg.sender == kernelGateway,
            "Only gateway can call this function.");
        _;
    }

    /* External / public functions */

    constructor(
        address _kernelGateway,
        OrganizationInterface _organization
    )
        public
        UtilityToken(
            OST_TOKEN_MAINNET,
            OST_TOKEN_SYMBOL,
            OST_TOKEN_NAME,
            OST_TOKEN_DECIMALS,
            _organization
        )
    {
        require(_kernelGateway != address(0),
            "Kernel gateway must not be null.");

        kernelGateway = _kernelGateway;
    }

    // function registerKernel(
    //     uint256 _height,

    // )
    //     external
    //     onlyKernelGateway
    // {

    // }

    function increaseSupply(
        address payable _account,
        uint256 _amount
    )
        external
        onlyKernelGateway
        returns (bool success_)
    {
        // Supply can only be increased to deposit in the gas market.
        // note: don't require this condition to allow the gateway to
        // record the failure of the message.
        if (_account == address(this)) {
            // deposit OST into the gas market
            success_ = super.increaseSupplyInternal(address(this), _amount);
        } else {
            success_ = false;
        }
    }

    function transfer(
        address _to,
        uint256 _value
    )
        public
        returns (bool success_)
    {
        require(false,
            "Transfers on the gas market are not allowed.");
        success_ = false;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        returns (bool success_)
    {
        require(false,
            "Transfers on the gas market are not allowed.");
        success_ = false;
    }
}