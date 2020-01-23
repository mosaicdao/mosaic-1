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
 * @title Genesis origin protocore contract is a storage contract that holds
 *        the initial values required by the contract that were written in the
 *        genesis block.
 */
contract GenesisOriginProtocore {

    /* Storage */

    /** Source block hash */
    bytes32 public genesisBlockHash;

    /** Source block number */
    uint256 public genesisBlockNumber;
}