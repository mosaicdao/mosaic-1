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
     * @return Block hash and block number of finalized genesis checkpoint.
     *
     * \post Sets `selfProtocore` to the given value.
     * \post Sets `domainSeparator` to the given value.
     * \post Sets `epochLength` to the given value.
     * \post Sets `metachainId` to the given value.
     * \post Sets genesis link.
     */
    function setup()
        external
        onlyCoconsensus
        returns (
            bytes32 finalizedBlockHash_,
            uint256 finalizedBlockNumber_
        )
    {
        selfProtocore = genesisSelfProtocore;

        // The source transition hash should be zero for origin protocore.
        Protocore.setupProtocore(
            genesisMetachainId,
            genesisDomainSeparator,
            genesisEpochLength,
            genesisProposedMetablockHeight,
            genesisOriginParentVoteMessageHash,
            bytes32(0),
            genesisOriginSourceBlockHash,
            genesisOriginSourceBlockNumber,
            genesisOriginTargetBlockHash,
            genesisOriginTargetBlockNumber
        );

        finalizedBlockHash_ = genesisOriginTargetBlockHash;
        finalizedBlockNumber_ = genesisOriginTargetBlockNumber;
    }


    /* External Functions */

    /**
     * @notice openKernel() function marks the specified kernel
     *         as opened.
     *
     * @param _kernelHeight New kernel height.
     * @param _kernelHash New kernel hash.
     *
     * \pre Only coconsensus can call.
     * \pre Satisfies all pre conditions of Protocore::openKernelInternal().
     *
     * \post Satisfies all the post conditions of Protocore::openKernelInternal().
     */
    function openKernel(
        uint256 _kernelHeight,
        bytes32 _kernelHash
    )
        external
        onlyCoconsensus
    {
        Protocore.openKernelInternal(
            _kernelHeight,
            _kernelHash
        );
    }

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

    /**
     * @notice It registers a vote for a link specified by vote message hash.
     *         Validators sign a vote message and provides the signature.
     *
     * @dev It must satify pre and post conditions of
     *      Protocore::registerVoteInternal.
     *
     * @param _voteMessageHash Message hash of a vote.
     * @param _r The first 32 bytes of ECDSA signature of a validator.
     * @param _s The second 32 bytes of ECDSA signature of a validator.
     * @param _v The recovery id/value of ECDSA signature of a validator.
     */
    function registerVote(
        bytes32 _voteMessageHash,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        external
    {
        Protocore.registerVoteInternal(
            _voteMessageHash,
            _r,
            _s,
            _v
        );
    }


    /* Public Functions */

    /**
     * @notice inForwardValidatorSet() function calls on SelfProtocore contract
     *         to query the forward validator set.
     */
    function inForwardValidatorSet(address _validator, uint256 _height)
        public
        view
        returns (bool)
    {
        assert(selfProtocore != address(0));
        return ForwardValidatorSetAbstract(selfProtocore).inForwardValidatorSet(
            _validator,
            _height
        );
    }

    /**
     * @notice forwardValidatorSetCount() function calls on SelfProtocore contract
     *         to query the forward validator set.
     */
    function forwardValidatorSetCount(uint256 _height)
        public
        view
        returns (uint256)
    {
        assert(selfProtocore != address(0));
        return ForwardValidatorSetAbstract(selfProtocore).forwardValidatorSetCount(
            _height
        );
    }
}
