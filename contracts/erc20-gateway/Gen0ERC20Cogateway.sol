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

import "./ERC20Cogateway.sol";

/**
 * @title Implements ERC20Cogateway contract for gen0.
 */
contract Gen0ERC20Cogateway is ERC20Cogateway {

    /* External Functions */

    /**
     * @notice activate() function activates the contract.
     *
     * @dev The function sets corresponding genesis* variables inherited
     *      from GenesisERC20Cogateway contract and calls the parent class
     *      ERC20Cogateway::setup() function to initialize contract.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_erc20Gateway` is not 0.
     * \pre `_stateRootProvider` is not 0.
     * \pre `maxStorageRootItems` is not 0.
     *
     * \post Sets corresponding genesis* variables inherited from
     *      GenesisERC20Cogateway contract and calls ERC20Cogateway::setup()
     *      function to initialize the contract. Calling ERC20Cogateway::setup()
     *      also sets storage variable `activated` inherited from ERC20Cogateway
     *      contract and asserts that contract has not been previously
     *      activated.
     */
    function activate(
        bytes32 _metachainId,
        address _erc20Gateway,
        address _stateRootProvider,
        uint256 _maxStorageRootItems,
        uint8 _outboxStorageIndex
    )
        external
    {
        require(_metachainId != bytes32(0), "Metachain id is 0.");
        require(_erc20Gateway != address(0), "ERC20Cogateway's address is 0.");
        require(
            _stateRootProvider != address(0),
            "State root provider's address is 0."
        );
        require(
            _maxStorageRootItems != uint256(0),
            "Max storage root item count is 0."
        );

        genesisMetachainId = _metachainId;
        genesisERC20Gateway = _erc20Gateway;
        genesisStateRootProvider = _stateRootProvider;
        genesisMaxStorageRootItems = _maxStorageRootItems;
        genesisOutboxStorageIndex = _outboxStorageIndex;

        ERC20Cogateway.setup();
    }

    /**
     * @notice setup() function is a dummy function for this contract.
     *
     * @dev Implementation does not mark the contract as private (as it has
     *      dummy implementation, it makes sense), because components
     *      accepting ERC20Cogateway interface might require this function
     *      to be there.
     */
    function setup()
        public
    {
    }
}
