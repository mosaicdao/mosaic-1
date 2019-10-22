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

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const ProxyFactoryTruffleArtifact = require('../../build/contracts/ProxyFactory.json');
const AxiomUtils = require('./utils.js');

let config = {};

contract('Axiom::constructor', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      techGov: accountProvider.get(),
      consensusMasterCopy: accountProvider.get(),
      coreMasterCopy: accountProvider.get(),
      committeeMasterCopy: accountProvider.get(),
      reputationMasterCopy: accountProvider.get(),
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(config);
  });

  contract('Negative Tests', () => {
    it('should fail when technical governance address is 0', async () => {
      await Utils.expectRevert(
        AxiomUtils.deployAxiom(
          Utils.NULL_ADDRESS,
          config.consensusMasterCopy,
          config.coreMasterCopy,
          config.committeeMasterCopy,
          config.reputationMasterCopy,
          {
            from: accountProvider.get(),
          },
        ),
        'Tech gov address is 0.',
      );
    });

    it('should fail when consensus master copy address is 0', async () => {
      await Utils.expectRevert(
        AxiomUtils.deployAxiom(
          config.techGov,
          Utils.NULL_ADDRESS,
          config.coreMasterCopy,
          config.committeeMasterCopy,
          config.reputationMasterCopy,
          {
            from: accountProvider.get(),
          },
        ),
        'Consensus master copy adress is 0.',
      );
    });

    it('should fail when core master copy address is 0', async () => {
      await Utils.expectRevert(
        AxiomUtils.deployAxiom(
          config.techGov,
          config.consensusMasterCopy,
          Utils.NULL_ADDRESS,
          config.committeeMasterCopy,
          config.reputationMasterCopy,
          {
            from: accountProvider.get(),
          },
        ),
        'Core master copy adress is 0.',
      );
    });

    it('should fail when committee master copy address is 0', async () => {
      await Utils.expectRevert(
        AxiomUtils.deployAxiom(
          config.techGov,
          config.consensusMasterCopy,
          config.coreMasterCopy,
          Utils.NULL_ADDRESS,
          config.reputationMasterCopy,
          {
            from: accountProvider.get(),
          },
        ),
        'Committee master copy adress is 0.',
      );
    });

    it('should fail when reputation master copy address is 0', async () => {
      await Utils.expectRevert(
        AxiomUtils.deployAxiom(
          config.techGov,
          config.consensusMasterCopy,
          config.coreMasterCopy,
          config.committeeMasterCopy,
          Utils.NULL_ADDRESS,
          {
            from: accountProvider.get(),
          },
        ),
        'Reputation master copy adress is 0.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should deploy axiom contract', async () => {
      await AxiomUtils.deployAxiomWithConfig(config);
    });

    it('should verify the variables are set', async () => {
      const axiom = await AxiomUtils.deployAxiomWithConfig(config);

      const techGovFromContract = await axiom.techGov.call();
      assert.strictEqual(
        techGovFromContract,
        config.techGov,
        'Technical governance address should match.',
      );

      const consensusMasterCopyFromContract = await axiom.consensusMasterCopy.call();
      assert.strictEqual(
        consensusMasterCopyFromContract,
        config.consensusMasterCopy,
        'Consensus master copy address should match.',
      );

      const coreMasterCopyFromContract = await axiom.coreMasterCopy.call();
      assert.strictEqual(
        coreMasterCopyFromContract,
        config.coreMasterCopy,
        'Core master copy address should match.',
      );

      const committeeMasterCopyFromContract = await axiom.committeeMasterCopy.call();
      assert.strictEqual(
        committeeMasterCopyFromContract,
        config.committeeMasterCopy,
        'Committee master copy address should match.',
      );

      const reputationMasterCopyFromContract = await axiom.reputationMasterCopy.call();
      assert.strictEqual(
        reputationMasterCopyFromContract,
        config.reputationMasterCopy,
        'Reputation master copy address should match.',
      );
    });

    it('should get correct value for reputation setup call prefix', async () => {
      const axiom = await AxiomUtils.deployAxiomWithConfig(config);

      const callPrefix = await axiom.REPUTATION_SETUP_CALLPREFIX.call();
      const expectedCallPrefix = Utils.getCallPrefix(AxiomUtils.ReputationSetupCallPrefix);

      assert.strictEqual(
        callPrefix,
        expectedCallPrefix,
        'Call prefix for reputation should match.',
      );
    });

    it('should get correct value for consensus setup call prefix', async () => {
      const axiom = await AxiomUtils.deployAxiomWithConfig(config);

      const callPrefix = await axiom.CONSENSUS_SETUP_CALLPREFIX.call();
      const expectedCallPrefix = Utils.getCallPrefix(AxiomUtils.ConsensusSetupCallPrefix);

      assert.strictEqual(
        callPrefix,
        expectedCallPrefix,
        'Call prefix for consensus should match.',
      );
    });

    it('should get correct value for epochLength constant', async () => {
      const axiom = await AxiomUtils.deployAxiomWithConfig(config);

      const epochLength = await axiom.EPOCH_LENGTH.call();
      const expectedEpochLength = 100;

      assert.strictEqual(
        epochLength.eqn(expectedEpochLength),
        true,
        `Epoch length ${epochLength.toString(10)} from contract must be equal to ${expectedEpochLength}`,
      );
    });
  });
});
