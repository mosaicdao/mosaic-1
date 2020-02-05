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

const SelfProtocoreUtils = require('./utils.js');
const ProtocoreUtils = require('../protocore/utils.js');
const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3.js');

const TestSelfProtocore = artifacts.require('TestSelfProtocore');

contract('SelfProtocore::proposeLink', (accounts) => {
  let config = {};
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = SelfProtocoreUtils.setupInitialConfig(accountProvider);

    config.genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
      config.domainSeparator,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
    );

    config.selfProtocore = await TestSelfProtocore.new();
    await config.selfProtocore.setCoconsensus(config.coconsensusAddress);
    await SelfProtocoreUtils.setupSelfProtocore(config);

    config.sourceKernelHash = Utils.getRandomHash();
    await config.selfProtocore.setOpenKernelHash(config.sourceKernelHash);

    config.openKernelHeight = new BN(20);
    await config.selfProtocore.setOpenKernelHeight(config.openKernelHeight);
  });

  contract('Positive Tests', async () => {
    it('should propose a valid link', async () => {
      const targetBlockHash = Utils.getRandomHash();
      const currentBlockNumber = await web3.eth.getBlockNumber();
      const targetBlockNumber = config.epochLength.muln(currentBlockNumber);

      const sourceOriginObservation = Utils.getRandomHash();
      const sourceDynasty = config.openKernelHeight;
      const sourceAccumulatedGas = new BN(10000);
      const sourceCommitteeLock = Utils.getRandomHash();

      await config.selfProtocore.proposeLink(
        config.genesisVoteMessageHash,
        targetBlockHash,
        targetBlockNumber,
        config.sourceKernelHash,
        sourceOriginObservation,
        sourceDynasty,
        sourceAccumulatedGas,
        sourceCommitteeLock,
      );
      const sourceTransitionHash = SelfProtocoreUtils.hashSourceTransition(
        config.domainSeparator,
        config.sourceKernelHash,
        sourceOriginObservation,
        sourceDynasty,
        sourceAccumulatedGas,
        sourceCommitteeLock,
      );

      const voteMessageHash = ProtocoreUtils.hashVoteMessage(
        config.domainSeparator,
        sourceTransitionHash,
        config.genesisTargetBlockHash,
        targetBlockHash,
        config.genesisTargetBlockNumber,
        targetBlockNumber,
      );

      const voteMessageObject = await config.selfProtocore.links.call(
        voteMessageHash,
      );

      assert.strictEqual(
        voteMessageObject.parentVoteMessageHash,
        config.genesisVoteMessageHash,
        'Incorrect parent vote message hash',
      );

      assert.strictEqual(
        voteMessageObject.sourceTransitionHash,
        sourceTransitionHash,
        'Incorrect source transition hash',
      );

      assert.strictEqual(
        voteMessageObject.targetBlockHash,
        targetBlockHash,
        'Incorrect target block hash',
      );

      assert.isOk(
        targetBlockNumber.eq(voteMessageObject.targetBlockNumber),
        `Expected target block number is ${targetBlockNumber} `
        + `but got ${voteMessageObject.targetBlockNumber}`,
      );

      assert.isOk(
        config.openKernelHeight.eq(voteMessageObject.proposedMetablockHeight),
        `Expected target block number is ${config.openKernelHeight} `
         + `but got ${voteMessageObject.proposedMetablockHeight}`,
      );

      assert.isOk(
        ProtocoreUtils.isRegistered(voteMessageObject.targetFinalisation),
        'Target finalisation status must be registered',
      );
    });
  });
});
