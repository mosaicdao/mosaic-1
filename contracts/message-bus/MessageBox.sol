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

import "../proxies/MasterCopyNonUpgradable.sol";

contract MessageBox is MasterCopyNonUpgradable {

    /** Mapping to indicate that message hash exists in outbox. */
    mapping(bytes32 => bool) public outbox;

    /** Mapping to indicate that message hash exists in inbox. */
    mapping(bytes32 => bool) public inbox;

    /**
     * Position of outbox in struct MessageBox.
     * This is used to generate storage Merkel proof.
     * @dev: This is 1 considering that master copy address is always
     * at location 0
     */
    uint8 public constant OUTBOX_OFFSET = 1;

    /**
     * Position of inbox in struct MessageBox.
     * This is used to generate storage merkel proof.
     * @dev: This is 1 considering that master copy address is always
     * at location 0 and outbox is at location 1.
     */
    uint8 public constant INBOX_OFFSET = 2;
}
