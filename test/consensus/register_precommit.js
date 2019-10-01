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
const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');

const Consensus = artifacts.require('ConsensusTest');

contract('Consensus::registerPrecommit', (accounts) => {
  let consensus;
  const testInputs = {};
  const accountProvider = new Utils.AccountProvider(accounts);

  beforeEach(async () => {
    // Populate the input data.
    testInputs.committeeSize = new BN(1000);
    testInputs.coreAddress1 = accountProvider.get();
    testInputs.coreAddress2 = accountProvider.get();
    testInputs.proposal1 = web3.utils.sha3('PROPOSAL_1');
    testInputs.proposal2 = web3.utils.sha3('PROPOSAL_2');
    consensus = await Consensus.new(testInputs.committeeSize);
  });

  contract('Negative Tests', async () => {
    it('should fail when caller is not core address', async () => {
      await Utils.expectRevert(
        consensus.registerPrecommit(
          testInputs.proposal1,
          {
            from: testInputs.coreAddress1,
          },
        ),
        'Caller must be an active core.',
      );
    });

    it('should fail when a precommit already exists for a core address', async () => {
      await consensus.setCoreStatus(
        testInputs.coreAddress1,
        consensusUtil.CORE_STATUS_ACTIVE,
      );

      await consensus.registerPrecommit(
        testInputs.proposal1,
        {
          from: testInputs.coreAddress1,
        },
      );

      await Utils.expectRevert(
        consensus.registerPrecommit(
          testInputs.proposal2,
          {
            from: testInputs.coreAddress1,
          },
        ),
        'There already exists a precommit of the core.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should pass when called with correct params', async () => {
      await consensus.setCoreStatus(
        testInputs.coreAddress1,
        consensusUtil.CORE_STATUS_ACTIVE,
      );

      const result = await consensus.registerPrecommit.call(
        testInputs.proposal1,
        {
          from: testInputs.coreAddress1,
        },
      );

      assert.strictEqual(
        result,
        true,
        'Contract must return true.',
      );

      const tx = await consensus.registerPrecommit(
        testInputs.proposal1,
        {
          from: testInputs.coreAddress1,
        },
      );

      assert.strictEqual(
        tx.receipt.status,
        true,
        'Transaction receipt status must be true.',
      );
    });

    it('should add the proposal in pre-commits mapping', async () => {
      await consensus.setCoreStatus(
        testInputs.coreAddress1,
        consensusUtil.CORE_STATUS_ACTIVE,
      );

      // The proposal must not exist by default.
      let proposalResult = await consensus.precommits(testInputs.coreAddress1);

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
        testInputs.proposal1,
        {
          from: testInputs.coreAddress1,
        },
      );

      // Proposal must exist now in mapping.
      proposalResult = await consensus.precommits(testInputs.coreAddress1);

      assert.strictEqual(
        proposalResult.proposal,
        testInputs.proposal1,
        'Proposal must be precommited.',
      );

      const expectedCommitteeFormationBlockHeight = new BN(tx.receipt.blockNumber)
        .add(consensusUtil.COMMITTEE_FORMATION_DELAY);

      assert.strictEqual(
        proposalResult.committeeFormationBlockHeight.eq(expectedCommitteeFormationBlockHeight),
        true,
        'Committee formation block height '
        + `${proposalResult.committeeFormationBlockHeight} is not equal to `
        + `expected value ${expectedCommitteeFormationBlockHeight}`,
      );
    });
  });
});
