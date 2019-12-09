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
const CoreUtils = require('./utils.js');
const Utils = require('../test_lib/utils.js');

const MockCore = artifacts.require('MockCore');

const config = {};

/** Proposes a metablock (with specified args) to the given core. */
async function proposeMetablock(
  proposalArgs, core,
) {
  const proposalHash = await core.proposeMetablock.call(
    proposalArgs.kernelHash,
    proposalArgs.originObservation,
    proposalArgs.dynasty,
    proposalArgs.accumulatedGas,
    proposalArgs.committeeLock,
    proposalArgs.source,
    proposalArgs.target,
    proposalArgs.sourceBlockHeight,
    proposalArgs.targetBlockHeight,
  );

  await core.proposeMetablock(
    proposalArgs.kernelHash,
    proposalArgs.originObservation,
    proposalArgs.dynasty,
    proposalArgs.accumulatedGas,
    proposalArgs.committeeLock,
    proposalArgs.source,
    proposalArgs.target,
    proposalArgs.sourceBlockHeight,
    proposalArgs.targetBlockHeight,
  );

  return proposalHash;
}

contract('Core::removeVote', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.consensusCoreArgs = {
      chainId: accountProvider.get(),
      epochLength: new BN(100),
      minValidatorCount: new BN(5),
      validatorJoinLimit: new BN(20),
      height: new BN(1),
      parent: CoreUtils.randomSha3(),
      gasTarget: new BN(1),
      dynasty: new BN(1),
      accumulatedGas: new BN(1),
      source: accountProvider.get(),
      sourceBlockHeight: new BN(100),
    };

    config.consensus = await CoreUtils.createConsensusCore(
      config.consensusCoreArgs.chainId,
      config.consensusCoreArgs.epochLength,
      config.consensusCoreArgs.minValidatorCount,
      config.consensusCoreArgs.validatorJoinLimit,
      config.consensusCoreArgs.height,
      config.consensusCoreArgs.parent,
      config.consensusCoreArgs.gasTarget,
      config.consensusCoreArgs.dynasty,
      config.consensusCoreArgs.accumulatedGas,
      config.consensusCoreArgs.sourceBlockHeight,
      { from: accountProvider.get() },
    );

    const coreAddress = await config.consensus.mockCore();
    config.core = await MockCore.at(coreAddress);

    const { validators } = await CoreUtils.openCore(
      config.consensus, config.core,
    );
    config.validators = validators;

    assert(validators.length >= 1);
    [config.validator0] = validators;

    const isValidator0 = await config.core.isValidator(config.validator0.address);
    assert(isValidator0);

    config.proposalArgs = {
      kernelHash: await config.core.openKernelHash(),
      originObservation: CoreUtils.randomSha3(),
      dynasty: new BN(2),
      accumulatedGas: new BN(2),
      committeeLock: CoreUtils.randomSha3(),
      source: CoreUtils.randomSha3(),
      target: CoreUtils.randomSha3(),
      sourceBlockHeight: config.consensusCoreArgs.sourceBlockHeight
        .add(config.consensusCoreArgs.epochLength
          .mul(new BN(2))),
      targetBlockHeight: config.consensusCoreArgs.sourceBlockHeight
        .add(config.consensusCoreArgs.epochLength
          .mul(new BN(3))),
    };
    config.proposalHash = await proposeMetablock(config.proposalArgs, config.core);
    config.validator0.proposalSignature = await CoreUtils.signProposal(
      config.proposalHash, config.validator0.privateKey,
    );

    await config.core.registerVote(
      config.proposalHash,
      config.validator0.proposalSignature.r,
      config.validator0.proposalSignature.s,
      config.validator0.proposalSignature.v,
    );
  });

  contract('Negative Tests', async () => {
    it('should fail if consensus is not calling', async () => {
      await Utils.expectRevert(
        config.core.removeVote(
          config.validator0.address,
        ),
        'Only the consensus contract can call this function.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should remove a vote', async () => {
      let castVote = await config.core.votes(config.validator0.address);
      assert(castVote === config.proposalHash);

      let voteCount = await config.core.voteCounts(castVote);

      assert.isOk(
        voteCount.count.eqn(1),
      );
      assert.isOk(
        voteCount.height.eq(config.consensusCoreArgs.height),
      );
      assert.isOk(
        voteCount.dynasty.eq(config.proposalArgs.dynasty),
      );

      await config.consensus.removeVote(config.validator0.address);

      castVote = await config.core.votes(config.validator0.address);
      assert.strictEqual(
        castVote,
        Utils.ZERO_BYTES32,
      );

      voteCount = await config.core.voteCounts(castVote);

      assert.isOk(
        voteCount.count.eqn(0),
      );
      assert.isOk(
        voteCount.height.eqn(0),
      );
      assert.isOk(
        voteCount.dynasty.eqn(0),
      );
    });

    it('should ignore if validator\'s address is null', async () => {
      await config.consensus.removeVote(Utils.NULL_ADDRESS);
    });

    it('should ignore if validator is not active', async () => {
      await config.consensus.removeVote(accountProvider.get());
    });
  });
});
