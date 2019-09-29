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

const Consensus = artifacts.require('Consensus');

contract('Consensus::constructor', () => {
  beforeEach(async () => {
  });

  contract('Negative Tests', async () => {
    it('should fail if committee size is 0', async () => {
      await Utils.expectRevert(
        Consensus.new(new BN(0)),
        'Committee size is 0.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should construct given sensible parameters', async () => {
      const expectedcommitteeSize = new BN(1000);
      const consensus = await Consensus.new(expectedcommitteeSize);
      assert.isOk(consensus);

      // Verify if the committee size is set on construction.
      const committeeSize = await consensus.committeeSize.call();
      await assert.equal(
        committeeSize.eq(expectedcommitteeSize),
        true,
        `Committee size value from contract ${committeeSize} `
        + `must be equal to expected value ${expectedcommitteeSize}`,
      );

      // Expected sentinelAddress
      const expectedSentinelCommittee = '0x0000000000000000000000000000000000000001';

      // Verify if committee mapping has initial sentinel committee address.
      const sentinelAddress = await consensus.committees.call(expectedSentinelCommittee);
      await assert.strictEqual(
        sentinelAddress,
        expectedSentinelCommittee,
        `Sentinel committees value from contract ${sentinelAddress} `
        + `must be equal to expected value ${expectedSentinelCommittee}`,
      );
    });
  });

  contract('Assure constants', async () => {
    let consensus; // Consensus contract object.

    before(async () => {
      consensus = await Consensus.new(new BN(1));
    });

    it('Verify committee formation delay constant value', async () => {
      // Assert committee formation delay constant value.
      const committeeFormationDelay = await consensus.COMMITTEE_FORMATION_DELAY.call();
      await assert.equal(
        committeeFormationDelay.eq(consensusUtil.COMMITTEE_FORMATION_DELAY),
        true,
        `Committee formation delay value from contract ${committeeFormationDelay} `
        + `must be equal to expected value ${consensusUtil.COMMITTEE_FORMATION_DELAY}`,
      );
    });

    it('Verify committee formation length constant value', async () => {
      // Assert committee formation length constant value.
      const committeeFormationLength = await consensus.COMMITTEE_FORMATION_LENGTH.call();
      await assert.equal(
        committeeFormationLength.eq(consensusUtil.COMMITTEE_FORMATION_LENGTH),
        true,
        `Committee formation length value from contract ${committeeFormationLength} `
        + `must be equal to expected value ${consensusUtil.COMMITTEE_FORMATION_LENGTH}`,
      );
    });

    it('Verify core status halted constant value', async () => {
      // Assert core status halted constant.
      const coreStatusHalted = await consensus.CORE_STATUS_HALTED.call();
      await assert.strictEqual(
        coreStatusHalted,
        consensusUtil.CORE_STATUS_HALTED,
        `Core status halted value from contract ${coreStatusHalted} `
        + `must be equal to expected value ${consensusUtil.CORE_STATUS_HALTED}`,
      );
    });

    it('Verify core status corrupted constant value', async () => {
      // Assert core status corrupted constant.
      const coreStatusCorrupted = await consensus.CORE_STATUS_CORRUPTED.call();
      await assert.strictEqual(
        coreStatusCorrupted,
        consensusUtil.CORE_STATUS_CORRUPTED,
        `Core status corrupted value from contract ${coreStatusCorrupted} `
        + `must be equal to expected value ${consensusUtil.CORE_STATUS_CORRUPTED}`,
      );
    });

    it('Verify sentinel committees constant value', async () => {
      // Assert initial sentinel committee pointer address.
      const sentinelCommittee = await consensus.SENTINEL_COMMITTEES.call();
      await assert.strictEqual(
        sentinelCommittee,
        consensusUtil.SENTINEL_COMMITTEES,
        `Sentinel committees value from contract ${sentinelCommittee} `
        + `must be equal to expected value ${consensusUtil.SENTINEL_COMMITTEES}`,
      );
    });
  });
});
