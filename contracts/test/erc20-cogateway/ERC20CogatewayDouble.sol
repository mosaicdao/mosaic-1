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

import "../../erc20-gateway/ERC20Cogateway.sol";

/**
 * @title It is used for testing ERC20Cogateway contract.
 */
contract ERC20CogatewayDouble is ERC20Cogateway {

    /* External Functions */

    /**
     * @notice It is used to setup genesis params used to
     *         setup ERC20Cogateway contract.
     */
    function setupGenesis(
        bytes32 _genesisMetachainId,
        address _genesisERC20Gateway,
        address _genesisStateRootProvider,
        uint256 _genesisMaxStorageRootItems,
        uint8 _genesisOutboxStorageIndex,
        address _genesisUtilityTokenMasterCopy
    )
        external
    {
        genesisMetachainId = _genesisMetachainId;
        genesisERC20Gateway = _genesisERC20Gateway;
        genesisStateRootProvider = _genesisStateRootProvider;
        genesisMaxStorageRootItems = _genesisMaxStorageRootItems;
        genesisOutboxStorageIndex = _genesisOutboxStorageIndex;
        genesisUtilityTokenMastercopy = _genesisUtilityTokenMasterCopy;
    }

    /**
     * @notice Sets storage root at specific block number.
     */
    function setStorageRoot(
        uint256 _blockNumber,
        bytes32 _storageRoot
    )
        external
    {
        storageRoots[_blockNumber] = _storageRoot;
    }

    /**
     * @notice Sets inbound channel identifier.
     */
    function setInboundChannelIdentifier(bytes32 _inboundChannelIdentifier)
        external
    {
        inboundChannelIdentifier = _inboundChannelIdentifier;
    }
}
