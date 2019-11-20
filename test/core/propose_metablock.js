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

const BN = require('bn.js');

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const CoreUtils = require('./utils.js');

const Core = artifacts.require('Core');

let config = {};
let proposal = {};

async function openCore(
  accountProvider,
  core,
) {
  const minVal = await core.minimumValidatorCount.call();

  const joinDuringCreationPromises = [];
  for (let i = 0; i < minVal.toNumber(10); i += 1) {
    const validator = accountProvider.get();
    joinDuringCreationPromises.push(config.mockConsensus.joinDuringCreation(validator));
  }

  await Promise.all(joinDuringCreationPromises);
  const coreStatus = await config.core.coreStatus.call();
  assert.isOk(
    CoreUtils.isCoreOpened(coreStatus),
  );
}

async function proposeMetaBlock(
  core,
  kernelHash,
  originObservation,
  dynasty,
  accumulatedGas,
  committeeLock,
  source,
  target,
  sourceBlockHeight,
  targetBlockHeight,
  txOptions = {},
) {
  const proposalHash = await core.proposeMetablock.call(
    kernelHash,
    originObservation,
    dynasty,
    accumulatedGas,
    committeeLock,
    source,
    target,
    sourceBlockHeight,
    targetBlockHeight,
    txOptions,
  );

  await core.proposeMetablock(
    kernelHash,
    originObservation,
    dynasty,
    accumulatedGas,
    committeeLock,
    source,
    target,
    sourceBlockHeight,
    targetBlockHeight,
    txOptions,
  );

  return proposalHash;
}

contract('Core::proposeMetablock', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      chainId: Utils.NULL_ADDRESS,
      epochLength: new BN(100),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(0),
      dynasty: new BN(0),
      accumulatedGas: new BN(0),
      source: Utils.ZERO_BYTES32,
      sourceBlockHeight: new BN(0),
      deployer: accountProvider.get(),
    };

    proposal = {
      kernelHash: Utils.ZERO_BYTES32,
      originObservation: CoreUtils.randomSha3(),
      dynasty: new BN(1),
      accumulatedGas: new BN(1),
      committeeLock: CoreUtils.randomSha3(),
      source: CoreUtils.randomSha3(),
      target: CoreUtils.randomSha3(),
      sourceBlockHeight: config.sourceBlockHeight
        .add(config.epochLength
          .mul(new BN(2))),
      targetBlockHeight: config.sourceBlockHeight
        .add(config.epochLength
          .mul(new BN(3))),
    };

    config.mockConsensus = await CoreUtils.createConsensusCore(
      config.chainId,
      config.epochLength,
      config.height,
      config.parent,
      config.gasTarget,
      config.dynasty,
      config.accumulatedGas,
      config.source,
      config.sourceBlockHeight,
      {
        from: config.deployer,
      },
    );

    const coreAddress = await config.mockConsensus.core.call();
    config.core = await Core.at(coreAddress);
    Object.freeze(config);

    await openCore(accountProvider, config.core);

    proposal.kernelHash = await config.core.openKernelHash.call();
  });

  contract('Positive Tests', () => {
    it('should accept proposals', async () => {
      const eoa = accountProvider.get();

      const proposalHash = await proposeMetaBlock(
        config.core,
        proposal.kernelHash,
        proposal.originObservation,
        proposal.dynasty,
        proposal.accumulatedGas,
        proposal.committeeLock,
        proposal.source,
        proposal.target,
        proposal.sourceBlockHeight,
        proposal.targetBlockHeight,
        {
          from: eoa,
        },
      );

      const voteCount = await config.core.voteCounts.call(proposalHash);
      assert.isOk(
        voteCount.height.eq(config.height),
      );
      assert.isOk(
        voteCount.dynasty.eq(proposal.dynasty),
      );
      assert.isOk(
        voteCount.count.eq(new BN(0)),
      );
    });
  });
});
