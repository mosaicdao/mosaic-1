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
 * @title Origin protocore - This contract finalizes the proposed blocks of origin chain.
 */
contract OriginProtocore is MasterCopyNonUpgradable, GenesisOriginProtocore, Protocore {

    /* Storage */

    /**
     * Address of self protocore.
     * @dev this is needed to get the inforamation related to validator. Origin
     *      protocore will not have validator set, instead it will query Self protocore
     *      contract.
     */
    address public selfProtocore;


    /* Special Functions */

    /**
     * @notice setup() function initializes the current contract.
     *
     * @dev These input params will be provided by the coconsensus contract.
     *      This can be called only by the coconsensus contract.
     *      Function requires:
     *          - Only coconsensus contract address can call this function
     *          - This function can be called only once
     *          - Input param selfProtocore must not be null
     *          - Input param epoch lengh must not be zero
     *
     * @param _metachainId Metachain id.
     * @param _core Core contract address.
     * @param _epochLength Epoch length.
     * @param _metablockHeight Metablock height.
     * @param _selfProtocore SelfProtocore contract address.
     *
     * \pre `_selfProtocore` is not 0.
     *
     * \post Sets selfProtocore to the given value.
     */
    function setup(
        bytes32 _metachainId,
        address _core,
        uint256 _epochLength,
        uint256 _metablockHeight,
        address _selfProtocore
    )
        external
        onlyCoconsensus
    {
        require(
            selfProtocore == address(0),
            "Origin protocore contract is already initialized."
        );
        require(
            _selfProtocore != address(0),
            "Self protocore contract address is null."
        );

        selfProtocore = _selfProtocore;

        // The source transition hash should be zero for origin protocore.
        Protocore.setup(
            _metachainId,
            _core,
            _epochLength,
            _metablockHeight,
            genesisOriginParentVoteMessageHash,
            bytes32(0),
            genesisOriginSourceBlockHash,
            genesisOriginSourceBlockNumber,
            genesisOriginTargetBlockHash,
            genesisOriginTargetBlockNumber
        );
    }
}
