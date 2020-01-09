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

import "../consensus/CoConsensusModule.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootI.sol";
import "../consensus-gateway/ConsensusGatewayBase.sol";
import "../consensus-gateway/ERC20GatewayBase.sol";
import "../consensus/CoConsensusI.sol";

contract ConsensusCogateway is MasterCopyNonUpgradable, MessageBus, ConsensusGatewayBase, ERC20GatewayBase, CoConsensusModule {

    /* Constants */

    /* Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /* Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /* External functions */

    /**
     * @notice It sets up consensus cogateway. It can only be called once.
     *
     * @param _metachainId Metachain id of a metablock.
     * @param _coConsensus Address of coConsensus contract.
     * @param _utMOST Address of most contract at auxiliary chain.
     * @param _consensusGateway Address of most contract at auxiliary chain.
     * @param _outboxStorageIndex Outbox Storage index of ConsensusGateway.
     * @param _maxStorageRootItems Max storage roots to be stored.
     * @param _metablockHeight Height of the metablock.
     */
    function setup(
        bytes32 _metachainId,
        address _coConsensus,
        ERC20I _utMOST,
        address _consensusGateway,
        uint8 _outboxStorageIndex,
        uint256 _maxStorageRootItems,
        uint256 _metablockHeight
    )
        external
    {
        /*
         * Setup method can only be called once because of the check for
         * outboundMessageIdentifier in setupMessageOutbox method of
         * MessageOutbox contract.
         */

        ConsensusGatewayBase.setup(_utMOST, _metablockHeight);

        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _consensusGateway
        );

        address anchor = CoConsensusI(_coConsensus).getAnchor(_metachainId);

        require(
            anchor != address(0),
            "Anchor address must not be 0."
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _consensusGateway,
            _outboxStorageIndex,
            StateRootI(anchor),
            _maxStorageRootItems
        );
    }
}
