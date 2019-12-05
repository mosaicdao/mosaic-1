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

contract('Core::assertPrecommit', (accounts) => {
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
    config.proposalHash = await proposeMetablock(
      config.proposalArgs, config.core,
    );
  });

  contract('Negative Tests', async () => {
    it('should revert if core has not precommitted', async () => {
      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Core has not precommitted to a proposal.',
      );
    });

    it('should revert if provided metablock does not match with precommit', async () => {
      await CoreUtils.precommitCore(
        config.core,
        config.proposalHash,
        config.validators,
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          CoreUtils.randomSha3(),
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          CoreUtils.randomSha3(),
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty.add(new BN(1)),
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas.add(new BN(1)),
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          CoreUtils.randomSha3(),
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          CoreUtils.randomSha3(),
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          CoreUtils.randomSha3(),
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight.add(config.consensusCoreArgs.epochLength),
          config.proposalArgs.targetBlockHeight,
        ),
        'Provided metablock does not match precommit.',
      );

      await Utils.expectRevert(
        config.core.assertPrecommit(
          config.proposalArgs.kernelHash,
          config.proposalArgs.originObservation,
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.committeeLock,
          config.proposalArgs.source,
          config.proposalArgs.target,
          config.proposalArgs.sourceBlockHeight,
          config.proposalArgs.targetBlockHeight.add(config.consensusCoreArgs.epochLength),
        ),
        'Provided metablock does not match precommit.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should pass if provided metablock matches with the precommit', async () => {
      await CoreUtils.precommitCore(
        config.core,
        config.proposalHash,
        config.validators,
      );

      const precommit = await config.core.precommit();

      const proposal = await config.core.assertPrecommit(
        config.proposalArgs.kernelHash,
        config.proposalArgs.originObservation,
        config.proposalArgs.dynasty,
        config.proposalArgs.accumulatedGas,
        config.proposalArgs.committeeLock,
        config.proposalArgs.source,
        config.proposalArgs.target,
        config.proposalArgs.sourceBlockHeight,
        config.proposalArgs.targetBlockHeight,
      );

      assert.strictEqual(
        proposal,
        precommit,
      );
    });
  });
});
