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

import "../reputation/ReputationI.sol";

interface ConsensusI {

    /**
     * @notice Gets the reputation contract address.
     *
     * @return Reputation contract address.
     */
    function reputation()
        external
        view
        returns (ReputationI reputation_);

    /** @notice Gets cores' validators minimum count and join limit. */
    function coreValidatorThresholds()
        external
        view
        returns (uint256 minimumValidatorCount_, uint256 joinLimit_);

    /**
     * @notice Precommits metablock from a core.
     *
     * @param _chainId Chain id to precommit a proposal.
     * @param _proposal Precommit proposal.
     */
    function precommitMetablock(
        bytes20 _chainId,
        bytes32 _proposal
    )
        external;

    /**
     * @notice Registers a committee's decision.
     *
     * @param _chainId Chain id to register committee decision.
     * @param _decision Committee's decision.
     */
    function registerCommitteeDecision(
        bytes20 _chainId,
        bytes32 _decision
    )
        external;

    /**
     * @notice Creates a new meta chain.
     *
     * @param _anchor Anchor address of the new meta-chain.
     * @param _epochLength Epoch length for the new meta-chain.
     * @param _rootBlockHeight Root block height.
     */
    function newMetaChain(
        address _anchor,
        uint256 _epochLength,
        uint256 _rootBlockHeight
    )
        external;
}
