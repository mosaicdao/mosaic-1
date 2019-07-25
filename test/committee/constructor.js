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

const CommitteeUtils = require('./utils.js');
const { AccountProvider } = require('../test_lib/utils.js');


contract('Committee::constructor', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  const config = {
    consensus: accountProvider.get(),
    committeeSize: new BN(10),
    dislocation: web3.utils.sha3('dislocation'),
    proposal: web3.utils.sha3('proposal'),
  };
  Object.freeze(config);

  contract('Negative Tests', () => {
    it('should fail if committee size is less than 3', async () => {
      Utils.expectThrow(
        CommitteeUtils.createCommittee(
          2, // committee size,
          config.dislocation,
          config.proposal,
          {
            from: config.consensus,
          },
        ),
        'Committee size must not be smaller than three.',
      );
    });

    it('should fail if a dislocation is 0', async () => {
      Utils.expectThrow(
        CommitteeUtils.createCommittee(
          config.committeeSize,
          '0x', // dislocation,
          config.proposal,
          {
            from: config.consensus,
          },
        ),
        'Dislocation must not be zero.',
      );
    });

    it('should fail if a proposal is 0', async () => {
      Utils.expectThrow(
        CommitteeUtils.createCommittee(
          config.committeeSize,
          config.dislocation,
          '0x', // proposal
          {
            from: config.consensus,
          },
        ),
        'Proposal must not be zero.',
      );
    });
  });

  contract('Assure constants', () => {
    it('should fail if super majority constants are inconsistent', async () => {
      const committee = await CommitteeUtils.createCommittee(
        config.committeeSize,
        config.dislocation,
        config.proposal,
        {
          from: config.consensus,
        },
      );

      const superMajorityNumerator = await committee.COMMITTEE_SUPER_MAJORITY_NUMERATOR.call();
      const superMajorityDenominator = await committee.COMMITTEE_SUPER_MAJORITY_DENOMINATOR.call();

      assert.isOk(
        2 * superMajorityNumerator > superMajorityDenominator,
      );
    });
  });

  contract('Positive Tests', () => {
    it('should construct given sensible parameters', async () => {
      const committee = await CommitteeUtils.createCommittee(
        config.committeeSize,
        config.dislocation,
        config.proposal,
        {
          from: config.consensus,
        },
      );

      const consensus = await committee.consensus.call();
      assert.strictEqual(
        consensus === config.consensus,
        true,
        `Consensus contract is set to ${consensus} and is not ${config.consensus}.`,
      );

      const proposal = await committee.proposal.call();
      assert.strictEqual(
        proposal === config.proposal,
        true,
        'Proposals don\'t match.',
      );

      const dislocation = await committee.dislocation.call();
      assert.strictEqual(
        dislocation === config.dislocation,
        true,
        'Dislocation doesn\'t match.',
      );

      const status = await committee.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isCommitteeOpen(status),
        'Committee status is not open upon creation.',
      );

      const actualQuorum = await committee.quorum.call();
      const superMajorityNumerator = await committee.COMMITTEE_SUPER_MAJORITY_NUMERATOR.call();
      const superMajorityDenominator = await committee.COMMITTEE_SUPER_MAJORITY_DENOMINATOR.call();
      const expectedQuorum = Math.floor(
        config.committeeSize * superMajorityNumerator / superMajorityDenominator,
      );

      assert.isOk(
        actualQuorum.eqn(expectedQuorum),
        'Quorum\'s do not match',
      );
    });
  });
});
