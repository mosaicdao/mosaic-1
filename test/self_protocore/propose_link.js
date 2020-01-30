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

const { AccountProvider } = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');
const ProtocoreUtils = require('../protocore/utils.js');
const SelfProtocoreUtils = require('./utils.js');

const TestSelfProtocore = artifacts.require('TestSelfProtocore');

contract('SelfProtocore::proposeLink', (accounts) => {
  const config = {};
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.coconsensusAddress = accountProvider.get();
    config.domainSeparator = Utils.getRandomHash();
    config.epochLength = new BN(5);
    config.metachainId = Utils.getRandomHash();
    config.metablockHeight = new BN(10);
    config.accumulatedGas = new BN(10);

    config.genesisKernelHeight = new BN(1);
    config.genesisKernelHash = Utils.getRandomHash();
    config.genesisParentVoteMessageHash = Utils.getRandomHash();
    config.genesisSourceTransitionHash = Utils.getRandomHash();
    config.genesisSourceBlockHash = Utils.getRandomHash();
    config.genesisTargetBlockHash = Utils.getRandomHash();
    config.genesisSourceBlockNumber = new BN(0);
    config.genesisTargetBlockNumber = new BN(config.epochLength);

    config.genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
      config.domainSeparator,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
    );
    config.genesisProposedMetablockHeight = new BN(1);

    config.selfProtocore = await TestSelfProtocore.new();
    await config.selfProtocore.setCoconsensus(config.coconsensusAddress);
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
      const sourceDynasty = new BN(10);
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

      assert.isOk(targetBlockNumber.eq(voteMessageObject.targetBlockNumber));

      assert.isOk(config.openKernelHeight.eq(voteMessageObject.proposedMetablockHeight));

      assert.isOk(voteMessageObject.forwardVoteCount.eqn(0));

      assert.isOk(voteMessageObject.forwardVoteCountNextHeight.eqn(0));

      assert.isOk(voteMessageObject.forwardVoteCountPreviousHeight.eqn(0));

      assert.isOk(ProtocoreUtils.isRegistered(voteMessageObject.targetFinalisation));
    });
  });
});
