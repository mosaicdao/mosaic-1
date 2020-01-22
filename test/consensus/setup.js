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
const ConsensusUtils = require('./utils');
const AxiomUtils = require('../axiom/utils');

const Consensus = artifacts.require('Consensus');

contract('Consensus::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let setupParams = {};
  let consensus;
  beforeEach(async () => {
    consensus = await Consensus.new();
    setupParams = {
      committeeSize: new BN(Utils.getRandomNumber(500)),
      minValidators: new BN(5),
      joinLimit: new BN(7),
      gasTargetDelta: new BN(Utils.getRandomNumber(999999)),
      coinbaseSplitPerMille: new BN(Utils.getRandomNumber(1000)),
      reputation: accountProvider.get(),
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(setupParams);
  });

  contract('Negative Tests', () => {
    it('should fail when committee size is 0', async () => {
      const params = Object.assign(
        {},
        setupParams,
        { committeeSize: new BN(0) },
      );
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, params),
        'Committee size is 0.',
      );
    });

    it('should fail when minimum validators are less or equal to 5', async () => {
      const params = Object.assign(
        {},
        setupParams,
        { minValidators: new BN(4) },
      );
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, params),
        'Min validator size must be greater or equal to 5.',
      );
    });

    it('should fail when max validator size is less than minimum validators', async () => {
      const params = Object.assign(
        {},
        setupParams,
        { joinLimit: new BN(3) },
      );
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, params),
        'Max validator size is less than minimum validator size.',
      );
    });

    it('should fail when gas target delta value is 0', async () => {
      const params = Object.assign(
        {},
        setupParams,
        { gasTargetDelta: new BN(0) },
      );
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, params),
        'Gas target delta is 0.',
      );
    });

    it('should fail when coin base split per mille is not in range 0..1000', async () => {
      const params = Object.assign(
        {},
        setupParams,
        { coinbaseSplitPerMille: new BN(1001) },
      );
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, params),
        'Coin base split per mille should be in range: 0..1000.',
      );
    });

    it('should fail when reputation contract address is 0', async () => {
      const params = Object.assign(
        {},
        setupParams,
        { reputation: Utils.NULL_ADDRESS },
      );
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, params),
        'Reputation contract address is 0.',
      );
    });

    it('should fail when consensus contract is already setup', async () => {
      await ConsensusUtils.setup(consensus, setupParams);
      await Utils.expectRevert(
        ConsensusUtils.setup(consensus, setupParams),
        'Consensus is already setup.',
      );
    });
  });

  contract('Positive Tests', () => {
    it.skip('should set the variables', async () => {
      await ConsensusUtils.setup(consensus, setupParams);

      const committeeSize = await consensus.committeeSize.call();
      assert.strictEqual(
        committeeSize.eq(setupParams.committeeSize),
        true,
        `Committee size ${committeeSize.toString(10)} from contract must be`
        + ` equal to ${setupParams.committeeSize.toString(10)}.`,
      );

      const minValidators = await consensus.minValidators.call();
      assert.strictEqual(
        minValidators.eq(setupParams.minValidators),
        true,
        `Minimum validator value ${minValidators.toString(10)} from contract must be`
        + ` equal to ${setupParams.minValidators.toString(10)}.`,
      );

      const joinLimit = await consensus.joinLimit.call();
      assert.strictEqual(
        joinLimit.eq(setupParams.joinLimit),
        true,
        `Maximum validator value ${joinLimit.toString(10)} from contract must be`
        + ` equal to ${setupParams.joinLimit.toString(10)}.`,
      );

      const gasTargetDelta = await consensus.gasTargetDelta.call();
      assert.strictEqual(
        gasTargetDelta.eq(setupParams.gasTargetDelta),
        true,
        `Gas target delta value ${gasTargetDelta.toString(10)} from contract must be`
        + ` equal to ${setupParams.gasTargetDelta.toString(10)}.`,
      );

      const coinbaseSplitPerMille = await consensus.coinbaseSplitPerMille.call();
      assert.strictEqual(
        coinbaseSplitPerMille.eq(setupParams.coinbaseSplitPerMille),
        true,
        `Coin base split permille value ${coinbaseSplitPerMille.toString(10)} from contract must be`
        + ` equal to ${setupParams.coinbaseSplitPerMille.toString(10)}.`,
      );

      const reputation = await consensus.reputation.call();
      assert.strictEqual(
        reputation,
        setupParams.reputation,
        'Reputation address in the contract is not set.',
      );

      const axiom = await consensus.axiom.call();
      assert.strictEqual(
        axiom,
        setupParams.txOptions.from,
        'Axiom address in the contract is not set.',
      );

      const expectedSentinelCommittee = ConsensusUtils.SentinelCommittee;
      const sentinelAddress = await consensus.committees.call(expectedSentinelCommittee);
      await assert.strictEqual(
        sentinelAddress,
        expectedSentinelCommittee,
        `Sentinel committees value from contract ${sentinelAddress} `
        + `must be equal to expected value ${expectedSentinelCommittee}`,
      );
    });
  });

  contract('Verify constants', () => {
    it('Verify minimum required validators size', async () => {
      const minimumRequiredValidators = await consensus.MIN_REQUIRED_VALIDATORS.call();
      await assert.strictEqual(
        minimumRequiredValidators.eqn(ConsensusUtils.MinimumRequiredValidators),
        true,
        `Minimum required value from contract ${minimumRequiredValidators} `
        + `must be equal to expected value ${ConsensusUtils.MinimumRequiredValidators}`,
      );
    });

    it('Verify committee formation delay constant value', async () => {
      const committeeFormationDelay = await consensus.COMMITTEE_FORMATION_DELAY.call();
      await assert.strictEqual(
        committeeFormationDelay.eqn(ConsensusUtils.CommitteeFormationDelay),
        true,
        `Committee formation delay value from contract ${committeeFormationDelay} `
        + `must be equal to expected value ${ConsensusUtils.CommitteeFormationDelay}`,
      );
    });

    it('Verify committee formation length constant value', async () => {
      const committeeFormationLength = await consensus.COMMITTEE_FORMATION_LENGTH.call();
      await assert.strictEqual(
        committeeFormationLength.eqn(ConsensusUtils.CommitteeFormationLength),
        true,
        `Committee formation length value from contract ${committeeFormationLength} `
        + `must be equal to expected value ${ConsensusUtils.CommitteeFormationLength}`,
      );
    });

    it.skip('Verify sentinel committees constant value', async () => {
      const sentinelCommittee = await consensus.SENTINEL_COMMITTEES.call();
      const expectedSentinelCommittee = ConsensusUtils.SentinelCommittee;
      await assert.strictEqual(
        sentinelCommittee,
        expectedSentinelCommittee,
        'Sentinel committee value must be equal to expected value',
      );
    });

    it('Verify core setup call prefix constant value', async () => {
      const coreSetupCallPrefix = await consensus.CORE_SETUP_CALLPREFIX.call();
      await assert.strictEqual(
        coreSetupCallPrefix,
        AxiomUtils.CoreSetupCallPrefix,
        'Core setup call must be equal to expected value',
      );
    });

    it('Verify committee setup call prefix constant value', async () => {
      const committeeSetupCallPrefix = await consensus.COMMITTEE_SETUP_CALLPREFIX.call();
      await assert.strictEqual(
        committeeSetupCallPrefix,
        AxiomUtils.CommitteeSetupCallPrefix,
        'Committee setup call must be equal to expected value',
      );
    });

    it('Verify maximum coinbase split per mille', async () => {
      const maximumCoinbaseSplitPerMille = await consensus.MAX_COINBASE_SPLIT_PER_MILLE.call();
      await assert.strictEqual(
        maximumCoinbaseSplitPerMille.eqn(ConsensusUtils.MaximumCoinbaseSplitPerMille),
        true,
        `Maximum coinbase split per mille value from contract ${maximumCoinbaseSplitPerMille} `
        + `must be equal to expected value ${ConsensusUtils.MaximumCoinbaseSplitPerMille}`,
      );
    });
  });
});
