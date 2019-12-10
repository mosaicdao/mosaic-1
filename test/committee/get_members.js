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
const web3 = require('../test_lib/web3.js');

const CommitteeUtils = require('./utils.js');

let config = {};

async function checkMembers(committee, expectedMembers) {
  const actualMembers = await committee.getMembers();

  assert.strictEqual(
    actualMembers.length,
    expectedMembers.length,
  );

  expectedMembers.forEach(
    (m) => {
      assert.notStrictEqual(
        actualMembers.indexOf(m),
        -1,
      );
    },
  );
}

contract('Committee::getMembers', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      committee: {
        metachainId: Utils.generateRandomMetachainId(),
        size: 3,
        dislocation: web3.utils.sha3('dislocation'),
        proposal: web3.utils.sha3('proposal'),
        consensus: accountProvider.get(),
      },
    };

    config.committee.contract = await CommitteeUtils.createCommittee(
      config.committee.metachainId,
      config.committee.consensus,
      config.committee.size,
      config.committee.dislocation,
      config.committee.proposal,
      {
        from: accountProvider.get(),
      },
    );

    config.committee.sentinelMembers = await config.committee.contract.SENTINEL_MEMBERS.call();

    Object.freeze(config);
  });

  contract('Positive Tests', async () => {
    it('checks retrieval of members', async () => {
      const committeeContract = config.committee.contract;

      const members = [];
      for (let i = 0; i < config.committee.size; i += 1) {
        members.push(
          accountProvider.get(),
        );
      }

      await checkMembers(
        committeeContract,
        [],
      );

      await committeeContract.enterCommittee(
        members[0],
        config.committee.sentinelMembers,
        {
          from: config.committee.consensus,
        },
      );

      await checkMembers(
        committeeContract,
        [members[0]],
      );

      await committeeContract.enterCommittee(
        members[1],
        config.committee.sentinelMembers,
        {
          from: config.committee.consensus,
        },
      );

      await checkMembers(
        committeeContract,
        [members[0], members[1]],
      );

      await committeeContract.enterCommittee(
        members[2],
        config.committee.sentinelMembers,
        {
          from: config.committee.consensus,
        },
      );

      await checkMembers(
        committeeContract,
        [members[0], members[1], members[2]],
      );
    });
  });
});
