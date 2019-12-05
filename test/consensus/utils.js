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

'use strict';

const web3 = require('../test_lib/web3.js');

const SentinelCommittee = '0x0000000000000000000000000000000000000001';
const CommitteeFormationDelay = 14;
const CommitteeFormationLength = 7;
const BlockSegmentLength = 256;
const MinimumRequiredValidators = 5;
const MaximumCoinbaseSplitPerMille = 1000;

async function setup(consensus, setupConfig) {
  return consensus.setup(
    setupConfig.committeeSize,
    setupConfig.minValidators,
    setupConfig.joinLimit,
    setupConfig.gasTargetDelta,
    setupConfig.coinbaseSplitPerMille,
    setupConfig.reputation,
    setupConfig.txOptions,
  );
}

async function getDislocation(committeeFormationBlockHeight) {
  // Calculate the expected dislocation.
  let segment = committeeFormationBlockHeight;
  const seedGenerators = [];
  for (let i = 0; i < CommitteeFormationLength; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    const block = await web3.eth.getBlock(segment);
    seedGenerators[i] = block.hash.substring(2);
    segment = segment.subn(1);
  }
  const dislocation = web3.utils.soliditySha3(`0x${seedGenerators.join('')}`);
  return dislocation;
}

async function join(consensus, joinParams) {
  await consensus.join(
    joinParams.chainId,
    joinParams.core,
    joinParams.withdrawalAddress,
    joinParams.txOptions,
  );
}

async function joinDuringCreation(consensus, joinParams) {
  await consensus.joinDuringCreation(
    joinParams.chainId,
    joinParams.core,
    joinParams.withdrawalAddress,
    joinParams.txOptions,
  );
}

async function callNewMetaChainOnConsensus(spyAxiom, params) {
  await spyAxiom.callNewMetaChainOnConsensus(
    params.consensus,
    params.chainId,
    params.epochLength,
    params.source,
    params.sourceBlockHeight,
  );
}

async function commit(consensus, params) {
  await consensus.commit(
    params.chainId,
    params.rlpBlockHeader,
    params.kernelHash,
    params.originObservation,
    params.dynasty.toString(10),
    params.accumulatedGas.toString(10),
    params.committeeLock,
    params.source,
    params.target,
    params.sourceBlockHeight.toString(10),
    params.targetBlockHeight.toString(10),
    params.txOptions,
  );
}
module.exports = {
  SentinelCommittee,
  CommitteeFormationDelay,
  CommitteeFormationLength,
  BlockSegmentLength,
  MinimumRequiredValidators,
  MaximumCoinbaseSplitPerMille,
  setup,
  getDislocation,
  join,
  joinDuringCreation,
  callNewMetaChainOnConsensus,
  commit,
  CoreLifetime: {
    undefined: 0,
    halted: 1,
    corrupted: 2,
    creation: 3,
    genesis: 4,
    active: 5,
  },
};
