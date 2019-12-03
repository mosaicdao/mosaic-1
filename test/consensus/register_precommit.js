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
const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');

const Consensus = artifacts.require('ConsensusTest');

contract('Consensus::registerPrecommit', (accounts) => {
  let consensus;
  const inputParams = {};
  const accountProvider = new Utils.AccountProvider(accounts);

  beforeEach(async () => {
    // Populate the input data.
    inputParams.committeeSize = new BN(1000);
    inputParams.coreAddress1 = accountProvider.get();
    inputParams.coreAddress2 = accountProvider.get();
    inputParams.proposal1 = Utils.getRandomHash();
    inputParams.proposal2 = Utils.getRandomHash();
    consensus = await Consensus.new();
  });

  contract('Negative Tests', async () => {
    it('should fail when caller is not core address', async () => {
      await Utils.expectRevert(
        consensus.registerPrecommit(
          inputParams.proposal1,
          {
            from: inputParams.coreAddress1,
          },
        ),
        'Caller must be an active core.',
      );
    });

    it('should fail when a precommit already exists for a core address', async () => {
      await consensus.setCoreLifetime(
        inputParams.coreAddress1,
        consensusUtil.CoreLifetime.genesis,
      );
      await consensus.registerPrecommit(
        inputParams.proposal1,
        {
          from: inputParams.coreAddress1,
        },
      );
      await Utils.expectRevert(
        consensus.registerPrecommit(
          inputParams.proposal2,
          {
            from: inputParams.coreAddress1,
          },
        ),
        'There already exists a precommit of the core.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should pass when called with correct params', async () => {
      await consensus.setCoreLifetime(
        inputParams.coreAddress1,
        consensusUtil.CoreLifetime.genesis,
      );

      const tx = await consensus.registerPrecommit(
        inputParams.proposal1,
        {
          from: inputParams.coreAddress1,
        },
      );

      assert.strictEqual(
        tx.receipt.status,
        true,
        'Transaction receipt status must be true.',
      );

      const coreLifetime = new BN(
        await consensus.coreLifetime.call(inputParams.coreAddress1),
      );

      assert.isOk(
        coreLifetime.eqn(consensusUtil.CoreLifetime.activated),
        'CoreLifetime status should changes to activated',
      );
    });

    it('should add the proposal in pre-commits mapping', async () => {
      await consensus.setCoreLifetime(
        inputParams.coreAddress1,
        consensusUtil.CoreLifetime.activated,
      );

      // The proposal must not exist by default.
      let proposalResult = await consensus.precommits(inputParams.coreAddress1);

      assert.strictEqual(
        proposalResult.proposal,
        Utils.ZERO_BYTES32,
        'Proposal must not exists before registering the precommit.',
      );

      assert.strictEqual(
        proposalResult.committeeFormationBlockHeight.eqn(0),
        true,
        'Committee formation block height '
        + `${proposalResult.committeeFormationBlockHeight} is not equal to `
        + `expected value ${0}`,
      );

      const tx = await consensus.registerPrecommit(
        inputParams.proposal1,
        {
          from: inputParams.coreAddress1,
        },
      );

      // Proposal must exist now in mapping.
      proposalResult = await consensus.precommits(inputParams.coreAddress1);

      assert.strictEqual(
        proposalResult.proposal,
        inputParams.proposal1,
        'Proposal must be precommited.',
      );

      const expectedCommitteeFormationBlockHeight = new BN(tx.receipt.blockNumber)
        .addn(consensusUtil.CommitteeFormationDelay);

      assert.strictEqual(
        proposalResult.committeeFormationBlockHeight.eq(expectedCommitteeFormationBlockHeight),
        true,
        'Committee formation block height '
        + `${proposalResult.committeeFormationBlockHeight} is not equal to `
        + `expected value ${expectedCommitteeFormationBlockHeight}`,
      );

      const coreLifetime = new BN(
        await consensus.coreLifetime.call(inputParams.coreAddress1),
      );

      assert.isOk(
        coreLifetime.eqn(consensusUtil.CoreLifetime.activated),
        'CoreLifetime status should noy change',
      );
    });
  });
});
