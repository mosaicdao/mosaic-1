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

import "../consensus/CoconsensusModule.sol";
import "../anchor/GenesisOriginObserver.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../anchor/StateRootProvider.sol";

/**
 * @title OriginObserver - Contract on the auxiliary chain that stores the
 *        state root of the origin chain.
 *
 * @notice This contract stores the state root and block height from the
 *         origin chain. This contract is Coconsensus module. Only coconsensus
 *         contract will be able to anchor the state root.
 */
contract OriginObserver is
    MasterCopyNonUpgradable,
    GenesisOriginObserver,
    CoconsensusModule,
    StateRootProvider
{
    /* Constants */

    /** Storage index for genesisBlockNumber */
    uint8 public constant genesisBlockNumberIndex = uint8(1);

    /** Storage index for genesisStateRoot */
    uint8 public constant genesisStateRootIndex = uint8(2);

    /** Storage index for MaxStateRootLimitCount */
    uint8 public constant genesisMaxStateRootLimitCountIndex = uint8(3);


    /* External functions */

    /**
     * @notice Setup function for origin observer contract.
     *
     * @dev This can be called by anyone only once. The check in StateRootProvider::setup
     *      ensures this in its circular buffer setup. Onother check is provided by
     *      StateRootProvider::anchoStateRoot can be only called once for a given block
     *      number and has to be increasing.
     */
    function setup() external {
        StateRootProvider.setup(genesisMaxStateRootLimitCount);
        StateRootProvider.anchorStateRootInternal(genesisBlockNumber, genesisStateRoot);
    }

    /**
     * @notice Anchor the state root for an (increasing) block number.
     *
     * @dev  Function requires:
     *          - Only coconsensus contract address can call this function.
     *
     * @param _blockNumber Block number for which state root needs to
     *                      update.
     * @param _stateRoot State root of input block number.
     */
    function anchorStateRoot(
        uint256 _blockNumber,
        bytes32 _stateRoot
    )
        external
        onlyCoconsensus
    {
        StateRootProvider.anchorStateRootInternal(_blockNumber, _stateRoot);
    }
}
