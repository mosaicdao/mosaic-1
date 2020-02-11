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

import "../../consensus-gateway/ConsensusCogateway.sol";

/**
 * @title ConsensusCogatewayDouble contract.
 *
 * @notice It is used for testing ConsensusCogateway contract.
 */
contract ConsensusCogatewayDouble is ConsensusCogateway {

    /* External Functions. */

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

