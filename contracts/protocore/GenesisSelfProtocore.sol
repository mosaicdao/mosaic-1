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
 * @title Genesis self protocore contract is a storage contract that holds
 *        the initial values required by the contract that were written in the
 *        genesis block. It stores target checkpoint, parent vote message hash,
 *        source transition hash, source dynasty number and source accumulated
 *        gas.
 */
contract GenesisSelfProtocore {

    /* Storage */

    /** Metachain id of the auxiliary chain. */
    bytes32 public genesisAuxiliaryMetachainId;

    /** Epoch length. */
    uint256 public genesisEpochLength;

    /** Initial metablock height. */
    uint256 public genesisMetablockHeight;

    /** Initial dynasty number */
    uint256 public genesisDynasty;

    /** Domain separator. */
    bytes32 public genesisDomainSeparator;

    /** Block hash of source checkpoint */
    bytes32 public genesisAuxiliarySourceBlockHash;

    /** Block number of source checkpoint */
    uint256 public genesisAuxiliarySourceBlockNumber;

    /** Block hash of target checkpoint */
    bytes32 public genesisAuxiliaryTargetBlockHash;

    /** Block number of target checkpoint */
    uint256 public genesisAuxiliaryTargetBlockNumber;

    /** Parent vote message hash */
    bytes32 public genesisAuxiliaryParentVoteMessageHash;

    /** Source transition hash */
    bytes32 public genesisAuxiliarySourceTransitionHash;

    /** Accumulated gas */
    uint256 public genesisAuxiliaryAccumulatedGas;
}
