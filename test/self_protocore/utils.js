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

'use strict';

const BN = require('bn.js');
const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');


function hashSourceTransition(
  domainSeparator,
  sourceKernelHash,
  sourceOriginObservation,
  sourceDynasty,
  sourceAccumulatedGas,
  sourceCommitteeLock,
) {
  const sourceTransitionTypeHash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      ['bytes32', 'bytes32', 'bytes32', 'uint256', 'uint256', 'bytes32'],
      [
        Utils.TRANSITION_TYPEHASH,
        sourceKernelHash,
        sourceOriginObservation,
        sourceDynasty.toString(10),
        sourceAccumulatedGas.toString(10),
        sourceCommitteeLock,
      ],
    ),
  );

  const sourceTransitionHash = web3.utils
    .soliditySha3(
      { t: 'bytes', v: '0x19' },
      { t: 'bytes', v: '0x01' },
      { t: 'bytes32', v: domainSeparator },
      { t: 'bytes32', v: sourceTransitionTypeHash },
    )
    .toString('hex');

  return sourceTransitionHash;
}

function setupInitialConfig(
  accountProvider,
  epochLength = new BN(5),
  metablockHeight = new BN(10),
  accumulatedGas = new BN(10),
  genesisSourceBlockNumber = new BN(0),
) {
  const config = {};
  config.coconsensusAddress = accountProvider.get();
  config.domainSeparator = Utils.getRandomHash();
  config.epochLength = epochLength;
  config.metachainId = Utils.getRandomHash();
  config.metablockHeight = metablockHeight;
  config.accumulatedGas = accumulatedGas;

  config.genesisParentVoteMessageHash = Utils.getRandomHash();
  config.genesisSourceTransitionHash = Utils.getRandomHash();
  config.genesisSourceBlockHash = Utils.getRandomHash();
  config.genesisTargetBlockHash = Utils.getRandomHash();
  config.genesisSourceBlockNumber = genesisSourceBlockNumber;
  config.genesisTargetBlockNumber = new BN(config.epochLength);

  return config;
}

async function setupSelfProtocore(config) {
  await config.selfProtocore.setGenesisStorage(
    config.genesisParentVoteMessageHash,
    config.genesisSourceTransitionHash,
    config.genesisSourceBlockHash,
    config.genesisSourceBlockNumber,
    config.genesisTargetBlockHash,
    config.genesisTargetBlockNumber,
    config.accumulatedGas,
  );

  await config.selfProtocore.setup(
    config.metachainId,
    config.domainSeparator,
    config.epochLength,
    config.metablockHeight,
  );
}

module.exports = {
  hashSourceTransition,
  setupInitialConfig,
  setupSelfProtocore,
};
