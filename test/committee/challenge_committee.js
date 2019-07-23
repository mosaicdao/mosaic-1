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

function compare(a, b) {
  return a.distance - b.distance;
}

let config = {};

async function enterMembers(accountProvider, committeeContract, members, consensus) {
  const sentinelMembers = await committeeContract.SENTINEL_MEMBERS.call();

  const enterPromises = [];
  for (let i = 0; i < members.length; i += 1) {
    enterPromises.push(
      committeeContract.enterCommittee(
        members[i],
        sentinelMembers,
        {
          from: consensus,
        },
      ),
    );
  }
  await Promise.all(enterPromises);
}

contract('Committee:challengeCommittee', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      committee: {
        size: 7,
        dislocation: web3.utils.sha3('dislocation'),
        proposal: web3.utils.sha3('proposal'),
        consensus: accountProvider.get(),
      },
    };

    config.committee.contract = await CommitteeUtils.createCommittee(
      config.committee.size,
      config.committee.dislocation,
      config.committee.proposal,
      {
        from: config.committee.consensus,
      },
    );

    config.committee.sentinelMembers = await config.committee.contract.SENTINEL_MEMBERS.call();

    const dist = [];
    for (let i = 0; i < config.committee.size + 2; i += 1) {
      const account = accountProvider.get();
      dist.push({
        address: account,
        distance: CommitteeUtils.distanceToProposal(
          config.committee.dislocation,
          account,
          config.committee.proposal,
        ),
      });
    }
    dist.sort(compare);

    config.committee.furthestMember = dist[config.committee.size + 1].address;
    config.committee.closestMember = dist[0].address;
    config.committee.memberToInitiateCooldown = dist[1].address;

    await enterMembers(
      accountProvider,
      config.committee.contract,
      dist.slice(1, config.committee.size + 1).map(
        d => d.address,
      ),
      config.committee.consensus,
    );

    await config.committee.contract.cooldownCommittee(
      {
        from: config.committee.memberToInitiateCooldown,
      },
    );

    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should fail if committee is not in cooling down mode', async () => {
      const consensus = accountProvider.get();
      const committee = await CommitteeUtils.createCommittee(
        3,
        web3.utils.sha3('dislocation'),
        web3.utils.sha3('proposal'),
        {
          from: consensus,
        },
      );

      await Utils.expectRevert(
        committee.challengeCommittee(
          accountProvider.get(),
          {
            from: consensus,
          },
        ),
        'Committee formation must be cooling down.',
      );
    });

    it('should fail if a caller is not consensus', async () => {
      await Utils.expectRevert(
        config.committee.contract.challengeCommittee(
          accountProvider.get(),
          {
            from: accountProvider.get(),
          },
        ),
        'Only the consensus contract can call this function.',
      );
    });

    it('should fail if challenged member is already in the committee', async () => {
      await Utils.expectRevert(
        config.committee.contract.challengeCommittee(
          config.committee.memberToInitiateCooldown,
          {
            from: config.committee.consensus,
          },
        ),
        'Member should not already be in the committee.',
      );
    });

    it('should fail if challenged member distance is greater or equal then '
     + 'furtest committee member', async () => {
      await Utils.expectRevert(
        config.committee.contract.challengeCommittee(
          config.committee.furthestMember,
          {
            from: config.committee.consensus,
          },
        ),
        'Member has been excluded.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks that committee is invalid after successfull challenge', async () => {
      await config.committee.contract.challengeCommittee(
        config.committee.closestMember,
        {
          from: config.committee.consensus,
        },
      );

      const status = await config.committee.contract.committeeStatus.call();
      CommitteeUtils.isInvalid(status);
    });
  });
});
