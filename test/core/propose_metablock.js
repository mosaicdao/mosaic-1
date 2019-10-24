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

async function proposeMetaBlock(
  core,
  proposalArgs,
  txOptions = {},
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
    txOptions,
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
    txOptions,
  );

  return proposalHash;
}

contract('Core::proposeMetablock', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      chainId: accountProvider.get(),
      epochLength: new BN(100),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(0),
      dynasty: new BN(0),
      accumulatedGas: new BN(1),
      source: accountProvider.get(),
      sourceBlockHeight: new BN(0),
      deployer: accountProvider.get(),
    };

    proposal = {
      kernelHash: Utils.ZERO_BYTES32,
      originObservation: CoreUtils.randomSha3(),
      dynasty: new BN(1),
      accumulatedGas: new BN(2),
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

    const coreAddress = await config.mockConsensus.mockCore();
    config.core = await Core.at(coreAddress);
    Object.freeze(config);

    await CoreUtils.openCore(accountProvider, config.mockConsensus, config.core);

    proposal.kernelHash = await config.core.openKernelHash();
  });

  contract('Negative Tests', async () => {
    it('should revert if a kernel hash does not match with an opened kernel hash', async () => {
      proposal.kernelHash = Utils.ZERO_BYTES32;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'A metablock can only be proposed for the open Kernel in this core.',
      );
    });

    it('should revert if an origin observation is 0', async () => {
      proposal.originObservation = Utils.ZERO_BYTES32;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Origin observation cannot be null.',
      );
    });

    it('should revert if a dynasty is not strictly greater from the committed one', async () => {
      proposal.dynasty = config.dynasty;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Dynasty must strictly increase.',
      );
    });

    it('should revert if a accumulated gas is not strictly greater '
    + 'from the committed one', async () => {
      proposal.accumulatedGas = config.accumulatedGas;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Accumulated gas must strictly increase.',
      );
    });

    it('should revert if a committee lock is 0', async () => {
      proposal.committeeLock = Utils.ZERO_BYTES32;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Committee lock cannot be null.',
      );
    });

    it('should revert if a source blockhash is 0', async () => {
      proposal.source = Utils.ZERO_BYTES32;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Source blockhash must not be null.',
      );
    });

    it('should revert if a target block hash is 0', async () => {
      proposal.target = Utils.ZERO_BYTES32;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Target blockhash must not be null.',
      );
    });

    it('should revert if a source block height is not strictly greater from'
    + 'the committed source block height', async () => {
      proposal.sourceBlockHeight = config.sourceBlockHeight;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Source block height must strictly increase.',
      );
    });

    it('should revert if a source is not a checkpoint', async () => {
      proposal.sourceBlockHeight = config.sourceBlockHeight + 1;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Source block height must be a checkpoint.',
      );
    });

    it('should revert if a source block hash matches with the committed one', async () => {
      proposal.source = config.source;
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Source blockhash cannot equal sealed source blockhash.',
      );
    });

    it('should revert if a target block height is not +1 epoch of '
    + 'a source block height', async () => {
      proposal.targetBlockHeight = proposal.sourceBlockHeight
        .add(config.epochLength.mul(new BN(2)));
      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Target block height must equal source block height plus one.',
      );
    });

    it('should revert if a proposal already exists', async () => {
      await proposeMetaBlock(
        config.core,
        proposal,
      );

      await Utils.expectRevert(
        proposeMetaBlock(
          config.core,
          proposal,
        ),
        'Proposal can only be inserted once.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should accept proposals', async () => {
      const proposalHash = await proposeMetaBlock(
        config.core,
        proposal,
      );

      const voteCount = await config.core.voteCounts(proposalHash);
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
