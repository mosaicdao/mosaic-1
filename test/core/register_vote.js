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
const CoreStatusUtils = require('../test_lib/core_status_utils.js');
const Utils = require('../test_lib/utils.js');

const CoreUtils = require('./utils.js');

const MockCore = artifacts.require('MockCore');

const config = {};

/** Generates a random proposal hash and signs with the given key. */
async function generateAndSignProposal(privateKey) {
  const proposalHash = CoreUtils.randomSha3();
  const proposalSignature = await CoreUtils.signProposal(proposalHash, privateKey);

  return {
    proposalHash,
    proposalSignature,
  };
}

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

contract('Core::registerVote', (accounts) => {
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
      config.consensusCoreArgs.source,
      config.consensusCoreArgs.sourceBlockHeight,
      { from: accountProvider.get() },
    );

    const coreAddress = await config.consensus.mockCore();
    config.core = await MockCore.at(coreAddress);

    const { validators } = await CoreUtils.openCore(
      config.consensus, config.core,
    );
    config.validators = validators;

    assert(validators.length >= 2);
    [config.validator0, config.validator1] = validators;

    const isValidator0 = await config.core.isValidator(config.validator0.address);
    assert(isValidator0);

    const isValidator1 = await config.core.isValidator(config.validator1.address);
    assert(isValidator1);

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
    config.validator1.proposalSignature = await CoreUtils.signProposal(
      config.proposalHash, config.validator1.privateKey,
    );

    config.higherDynastyProposalArgs = {
      kernelHash: await config.core.openKernelHash(),
      originObservation: CoreUtils.randomSha3(),
      dynasty: config.proposalArgs.dynasty.add(new BN(1)),
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
    config.higherDynastyProposalHash = await proposeMetablock(
      config.higherDynastyProposalArgs, config.core,
    );
    config.validator0.higherDynastyProposalSignature = await CoreUtils.signProposal(
      config.higherDynastyProposalHash, config.validator0.privateKey,
    );
    config.validator1.higherDynastyProposalSignature = await CoreUtils.signProposal(
      config.higherDynastyProposalHash, config.validator1.privateKey,
    );
  });

  contract('Negative Tests', async () => {
    it('should revert if core is not in precommitment window', async () => {
      const consensus = await CoreUtils.createConsensusCore(
        config.consensusCoreArgs.chainId,
        config.consensusCoreArgs.epochLength,
        config.consensusCoreArgs.minValidatorCount,
        config.consensusCoreArgs.validatorJoinLimit,
        config.consensusCoreArgs.height,
        config.consensusCoreArgs.parent,
        config.consensusCoreArgs.gasTarget,
        config.consensusCoreArgs.dynasty,
        config.consensusCoreArgs.accumulatedGas,
        config.consensusCoreArgs.source,
        config.consensusCoreArgs.sourceBlockHeight,
        { from: accountProvider.get() },
      );

      const coreAddress = await consensus.mockCore();
      const core = await MockCore.at(coreAddress);

      await Utils.expectRevert(
        core.registerVote(
          config.proposalHash,
          config.validator0.proposalSignature.r,
          config.validator0.proposalSignature.s,
          config.validator0.proposalSignature.v,
        ),
        'The precommitment window must be open.',
      );
    });

    it('should revert is a proposal is 0', async () => {
      await Utils.expectRevert(
        config.core.registerVote(
          Utils.ZERO_BYTES32,
          config.validator0.proposalSignature.r,
          config.validator0.proposalSignature.s,
          config.validator0.proposalSignature.v,
        ),
        'Proposal can not be null.',
      );
    });

    it('should revert if a proposal does not exist at open kernel height', async () => {
      const {
        proposalHash,
        proposalSignature,
      } = await generateAndSignProposal(config.validator0.privateKey);

      await Utils.expectRevert(
        config.core.registerVote(
          proposalHash,
          proposalSignature.r,
          proposalSignature.s,
          proposalSignature.v,
        ),
        'Proposal must be registered at open metablock height.',
      );
    });

    it('should revert if a validator is not active in this core', async () => {
      const validator = await CoreUtils.createValidator();
      const proposalSignature = await CoreUtils.signProposal(
        config.proposalHash,
        validator.privateKey,
      );

      await Utils.expectRevert(
        config.core.registerVote(
          config.proposalHash,
          proposalSignature.r,
          proposalSignature.s,
          proposalSignature.v,
        ),
        'Validator must be active in this core.',
      );
    });

    it('should revert if a validator is not active ', async () => {
      await config.consensus.setReputation(config.validator0.address, 0);
      await Utils.expectRevert(
        config.core.registerVote(
          config.proposalHash,
          config.validator0.proposalSignature.r,
          config.validator0.proposalSignature.s,
          config.validator0.proposalSignature.v,
        ),
        'Validator is slashed.',
      );
    });

    it('should revert if a validator has already voted for a proposal', async () => {
      await config.core.registerVote(
        config.proposalHash,
        config.validator0.proposalSignature.r,
        config.validator0.proposalSignature.s,
        config.validator0.proposalSignature.v,
      );

      await Utils.expectRevert(
        config.core.registerVote(
          config.proposalHash,
          config.validator0.proposalSignature.r,
          config.validator0.proposalSignature.s,
          config.validator0.proposalSignature.v,
        ),
        'Vote has already been cast.',
      );
    });

    it('should revert if a validator is changing its vote, however, the new proposal\'s dynasty '
      + ' is not strictly greater than old vote one.', async () => {
      await config.core.registerVote(
        config.proposalHash,
        config.validator0.proposalSignature.r,
        config.validator0.proposalSignature.s,
        config.validator0.proposalSignature.v,
      );

      const anotherProposalArgs = {
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

      const anotherProposalHash = await proposeMetablock(
        anotherProposalArgs, config.core,
      );

      const anotherProposalSignature = await CoreUtils.signProposal(
        anotherProposalHash, config.validator0.privateKey,
      );

      await Utils.expectRevert(
        config.core.registerVote(
          anotherProposalHash,
          anotherProposalSignature.r,
          anotherProposalSignature.s,
          anotherProposalSignature.v,
        ),
        'Vote can only be recast for higher dynasty numbers.',
      );
    });

    it('should revert if core has already precommitted and proposal does '
      + 'not match with it', async () => {
      await CoreUtils.precommitCore(
        config.core,
        config.proposalHash,
        config.validators,
      );

      await Utils.expectRevert(
        config.core.registerVote(
          config.higherDynastyProposalHash,
          config.validator0.higherDynastyProposalSignature.r,
          config.validator0.higherDynastyProposalSignature.s,
          config.validator0.higherDynastyProposalSignature.v,
        ),
        'Core has precommitted, only votes for precommitment are relevant.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should register a vote', async () => {
      await config.core.registerVote(
        config.proposalHash,
        config.validator0.proposalSignature.r,
        config.validator0.proposalSignature.s,
        config.validator0.proposalSignature.v,
      );

      const voteCount = await config.core.voteCounts(config.proposalHash);
      assert.isOk(
        voteCount.count.eqn(1),
        'Vote count for the proposal should be 1.',
      );
      assert.isOk(
        voteCount.height.eq(config.consensusCoreArgs.height),
        'Height of a vote count object should be equal to open kernel\'s '
        + 'height when the proposal was registered.',
      );
      assert.isOk(
        voteCount.dynasty.eq(config.proposalArgs.dynasty),
        'Dynasty of a vote count object should be equal to the proposal\'s dynasty.',
      );

      const validatorVote = await config.core.votes(config.validator0.address);
      assert.strictEqual(
        validatorVote,
        config.proposalHash,
      );
    });

    it('should register an initial vote', async () => {
      await config.core.registerVote(
        config.proposalHash,
        config.validator0.proposalSignature.r,
        config.validator0.proposalSignature.s,
        config.validator0.proposalSignature.v,
      );

      const voteCount = await config.core.voteCounts(config.proposalHash);
      assert.isOk(
        voteCount.count.eqn(1),
        'Vote count for the proposal should be 1.',
      );
      assert.isOk(
        voteCount.height.eq(config.consensusCoreArgs.height),
        'Height of a vote count object should be equal to open kernel\'s '
        + 'height when the proposal was registered.',
      );
      assert.isOk(
        voteCount.dynasty.eq(config.proposalArgs.dynasty),
        'Dynasty of a vote count object should be equal to the proposal\'s dynasty.',
      );

      const validatorVote = await config.core.votes(config.validator0.address);
      assert.strictEqual(
        validatorVote,
        config.proposalHash,
      );
    });

    it('should increment a vote count', async () => {
      await config.core.registerVote(
        config.proposalHash,
        config.validator0.proposalSignature.r,
        config.validator0.proposalSignature.s,
        config.validator0.proposalSignature.v,
      );

      const voteCount0 = await config.core.voteCounts(config.proposalHash);

      await config.core.registerVote(
        config.proposalHash,
        config.validator1.proposalSignature.r,
        config.validator1.proposalSignature.s,
        config.validator1.proposalSignature.v,
      );

      const voteCount1 = await config.core.voteCounts(config.proposalHash);

      assert.isOk(
        voteCount1.count.eq(voteCount0.count.add(new BN(1))),
        'Vote count should be incremented by one.',
      );

      assert.isOk(
        voteCount0.height.eq(voteCount1.height),
      );
      assert.isOk(
        voteCount0.dynasty.eq(voteCount1.dynasty),
      );

      const validatorVote0 = await config.core.votes(config.validator0.address);
      assert.strictEqual(
        validatorVote0,
        config.proposalHash,
      );

      const validatorVote1 = await config.core.votes(config.validator1.address);
      assert.strictEqual(
        validatorVote1,
        config.proposalHash,
      );
    });

    it('should update a vote', async () => {
      await config.core.registerVote(
        config.proposalHash,
        config.validator0.proposalSignature.r,
        config.validator0.proposalSignature.s,
        config.validator0.proposalSignature.v,
      );

      let voteCount = await config.core.voteCounts(config.proposalHash);

      assert.isOk(
        voteCount.count.eqn(1),
        'Vote count should be 1.',
      );

      let higherDynastyVoteCount = await config.core.voteCounts(
        config.higherDynastyProposalHash,
      );

      assert.isOk(
        higherDynastyVoteCount.count.eqn(0),
        'Vote count should be 0.',
      );

      await config.core.registerVote(
        config.higherDynastyProposalHash,
        config.validator0.higherDynastyProposalSignature.r,
        config.validator0.higherDynastyProposalSignature.s,
        config.validator0.higherDynastyProposalSignature.v,
      );

      voteCount = await config.core.voteCounts(config.proposalHash);

      assert.isOk(
        voteCount.count.eqn(0),
        'Vote count should be 0.',
      );

      higherDynastyVoteCount = await config.core.voteCounts(
        config.higherDynastyProposalHash,
      );

      assert.isOk(
        higherDynastyVoteCount.count.eqn(1),
        'Vote count should be 1.',
      );
    });

    it('should register a precommit once quorum is reached', async () => {
      const quorum = await config.core.quorum();

      assert(quorum > 0);
      assert(quorum <= config.validators.length);

      let txResponse = {};

      for (let i = 0; i < quorum; i += 1) {
        // eslint-disable-next-line no-await-in-loop
        const signature = await CoreUtils.signProposal(
          config.proposalHash, config.validators[i].privateKey,
        );

        // eslint-disable-next-line no-await-in-loop
        txResponse = await config.core.registerVote(
          config.proposalHash, signature.r, signature.s, signature.v,
        );

        if (i !== quorum - 1) {
          // eslint-disable-next-line no-await-in-loop
          const coreStatus = await config.core.coreStatus();
          assert.isNotOk(
            CoreStatusUtils.isCorePrecommitted(coreStatus),
          );
        }
      }

      const precommit = await config.core.precommit();
      assert.strictEqual(
        precommit,
        config.proposalHash,
      );

      const coreStatus = await config.core.coreStatus();
      assert.isOk(
        CoreStatusUtils.isCorePrecommitted(coreStatus),
      );

      const quorumBlockNumber = txResponse.receipt.blockNumber;
      const CORE_LAST_VOTES_WINDOW = await config.core.CORE_LAST_VOTES_WINDOW();
      const precommitClosureBlockHeight = await config.core.precommitClosureBlockHeight();

      assert.isOk(
        precommitClosureBlockHeight.eq(new BN(quorumBlockNumber).add(CORE_LAST_VOTES_WINDOW)),
      );

      const isPrecommitted = await config.consensus.isPrecommitted(config.core.address);
      assert.isOk(
        isPrecommitted,
      );
    });
  });
});
