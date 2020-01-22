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

/**
 * @title GenesisOriginObserver - Contract that holds the values written in genesis block.
 *
 * @notice This contract is the storage values that are written in the genesis file.
 *         These values will be used in the setup of the contract.
 */
contract GenesisOriginObserver {

    /* Public variables */

    /** Initial block number */
    uint256 public genesisBlockNumber;

    /** Initial state root */
    bytes32 public genesisStateRoot;
}