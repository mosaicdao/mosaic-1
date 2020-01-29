pragma solidity >=0.5.0 <0.6.0;

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
     * @param _metachainId Metachain id.
     * @param _metablockHeight Metablock height to precommit.
     * @param _metablockHashPrecommit Metablock hash to precommit.
     */
    function precommitMetablock(
        bytes32 _metachainId,
        uint256 _metablockHeight,
        bytes32 _metablockHashPrecommit
    )
        external;

    /**
     * @notice Registers a committee's decision.
     *
     * @param _metachainId Metachain id to register committee decision.
     * @param _decision Committee's decision.
     */
    function registerCommitteeDecision(
        bytes32 _metachainId,
        bytes32 _decision
    )
        external;

    /**
     * @notice Creates a new metachain.
     *
     * @return metachainId_ Metachain id.
     * @return anchor_ Address of anchor.
     */
    function newMetaChain() external returns (bytes32 metachainId_, address anchor_);

    /**
     * @notice Get anchor address for metachain id.
     *
     * @param _metachainId Metachain Id.
     *
     * @return Anchor contract address.
     */
    function getAnchor(bytes32 _metachainId) external returns(address anchor_);
}
