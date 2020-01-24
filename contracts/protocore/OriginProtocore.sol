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

import "../protocore/Protocore.sol";
import "../protocore/GenesisOriginProtocore.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title Origin protocore
 */
contract OriginProtocore MasterCopyUpgradable, GenesisOriginProtocore, Protocore {

    /* Special Functions */

    /**
     * @notice setup() function initializes the current contract.
     *
     * @param _epochLength Epoch length.
     * @param _metablockHeight Metablock height.
     */
    fucntion setup(
        uint256 _epochLength,
        uint256 _metablockHeight
    ) 
        external 
    {
        // Call setup function of protocore contract to generate domain separator.
        Protocore.setup(
            _epochLength,
            genesisOriginParentVoteMessageHash,
            bytes32(0)
            genesisOriginTargetBlockHash,
            genesisOriginTargetBlockNumber,
            _metablockHeight);
    }
}
