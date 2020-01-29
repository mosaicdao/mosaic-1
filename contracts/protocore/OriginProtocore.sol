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

import "../protocore/GenesisOriginProtocore.sol";
import "../protocore/Protocore.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

/**
 * @title Origin protocore - This contract finalizes the proposed blocks of origin chain.
 */
contract OriginProtocore is MasterCopyNonUpgradable, GenesisOriginProtocore, Protocore {

    /* Events */

    event LinkProposed(
        bytes32 parentVoteMessageHash,
        bytes32 targetBlockHash,
        uint256 targetBlockNumber
    );


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
     *      This can be called only by the coconsensus contract once.
     *
     * @param _metachainId Metachain id.
     * @param _domainSeparator Domain separator.
     * @param _epochLength Epoch length.
     * @param _metablockHeight Metablock height.
     * @param _selfProtocore SelfProtocore contract address.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_domainSeparator` is not 0.
     * \pre `_epochLength` is not 0.
     * \pre `_selfProtocore` is not 0.
     *
     * \post Sets `selfProtocore` to the given value.
     * \post Sets `domainSeparator` to the given value.
     * \post Sets `epochLength` to the given value.
     * \post Sets `metachainId` to the given value.
     * \post Sets genesis link.
     */
    function setup(
        bytes32 _metachainId,
        bytes32 _domainSeparator,
        uint256 _epochLength,
        uint256 _metablockHeight,
        address _selfProtocore
    )
        external
        onlyCoconsensus
    {
        require(
            _selfProtocore != address(0),
            "Self protocore contract address is null."
        );

        selfProtocore = _selfProtocore;

        // The source transition hash should be zero for origin protocore.
        Protocore.setup(
            _metachainId,
            _domainSeparator,
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


    /* External Functions */

    /**
     * @notice proposeLink() function proposes a valid link to be voted later by
     *         active validators.
     *
     * @dev Satisfies \pre and \post conditions of
     *      Protocore::proposeLinkInternal().
	 *
 	 * \post Emits LinkProposed event.
     */
    function proposeLink(
        bytes32 _parentVoteMessageHash,
        bytes32 _targetBlockHash,
        uint256 _targetBlockNumber
    )
        external
    {
        Protocore.proposeLinkInternal(
            _parentVoteMessageHash,
            bytes32(0),
            _targetBlockHash,
            _targetBlockNumber
        );

        emit LinkProposed(
            _parentVoteMessageHash,
            _targetBlockHash,
            _targetBlockNumber
        );
    }


    /* Public Functions */

    /**
     * @notice inForwardValidatorSet() function delegates the call to
     *         the stored self protocore contract.
     */
    function inForwardValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool)
    {
        assert(selfProtocore != address(0));
        return ForwardValidatorSetA(selfProtocore).inForwardValidatorSet(_validator, _height);
    }

    /**
     * @notice forwardValidatorCount() function delegates the call to
     *         the stored self protocore contract.
     */
    function forwardValidatorCount(uint256 _height)
        public
        view
        returns (uint256)
    {
        assert(selfProtocore != address(0));
        return ForwardValidatorSetA(selfProtocore).forwardValidatorCount(_height);
    }
}
