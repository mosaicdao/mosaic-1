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
  return a.distance.cmp(b.distance);
}

let config = {};

contract('Committee:enterCommittee', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      committee: {
        metachainId: Utils.generateRandomMetachainId(),
        size: 50,
        dislocation: web3.utils.sha3('dislocation'),
        proposal: web3.utils.sha3('proposal'),
        consensus: accountProvider.get(),
      },
      committee3: {
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

    config.committee3.contract = await CommitteeUtils.createCommittee(
      config.committee3.metachainId,
      config.committee3.consensus,
      config.committee3.size,
      config.committee3.dislocation,
      config.committee3.proposal,
      {
        from: accountProvider.get(),
      },
    );
    config.committee3.sentinelMembers = await config.committee3.contract.SENTINEL_MEMBERS.call();

    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should fail if caller is not the consensus contract', async () => {
      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          accountProvider.get(),
          config.committee.sentinelMembers,
          {
            from: accountProvider.get(),
          },
        ),
        'Only the consensus contract can call this function.',
      );
    });

    it('should fail if committee is not open', async () => {
      const validators = [];
      for (let i = 0; i < config.committee.size; i += 1) {
        validators.push(accountProvider.get());
      }
      assert(validators.length !== 0);
      const memberInitiatedCooldown = validators[0];

      for (let i = 0; i < validators.length; i += 1) {
      // eslint-disable-next-line no-await-in-loop
        await config.committee.contract.enterCommittee(
          validators[i],
          config.committee.sentinelMembers,
          {
            from: config.committee.consensus,
          },
        );
      }

      await config.committee.contract.cooldownCommittee({
        from: memberInitiatedCooldown,
      });

      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          accountProvider.get(),
          config.committee.sentinelMembers,
          {
            from: config.committee.consensus,
          },
        ),
        'Committee formation must be open.',
      );
    });

    it('should fail if validator address is 0', async () => {
      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          Utils.NULL_ADDRESS,
          config.committee.sentinelMembers,
          {
            from: config.committee.consensus,
          },
        ),
        'Validator address must not be 0.',
      );
    });

    it('should fail if validator address is sentinel-members', async () => {
      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          config.committee.sentinelMembers,
          config.committee.sentinelMembers,
          {
            from: config.committee.consensus,
          },
        ),
        'Validator address must not be sentinel for committee member.',
      );
    });

    it('should fail if validator address has been already entered', async () => {
      const validator = accountProvider.get();

      await config.committee.contract.enterCommittee(
        validator,
        config.committee.sentinelMembers,
        {
          from: config.committee.consensus,
        },
      );

      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          validator,
          config.committee.sentinelMembers,
          {
            from: config.committee.consensus,
          },
        ),
        'Validator must not already have entered.',
      );
    });

    it('should fail if further validator is not a member', async () => {
      const furtherValidator = accountProvider.get();
      const validator = accountProvider.get();

      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          validator,
          furtherValidator,
          {
            from: config.committee.consensus,
          },
        ),
        'Further validator must be in the committee.',
      );
    });

    it('should fail if a validator distance from the proposal '
     + 'is great then for the specified further-validator', async () => {
      const account1 = accountProvider.get();
      const account2 = accountProvider.get();

      const distanceFromProposal1 = CommitteeUtils.distanceToProposal(
        config.committee.dislocation,
        account1,
        config.committee.proposal,
      );

      const distanceFromProposal2 = CommitteeUtils.distanceToProposal(
        config.committee.dislocation,
        account2,
        config.committee.proposal,
      );

      let validator = '';
      let furtherValidator = '';
      if (distanceFromProposal1.gt(distanceFromProposal2)) {
        validator = account1;
        furtherValidator = account2;
      } else {
        validator = account2;
        furtherValidator = account1;
      }

      // Entering further validator.
      await config.committee.contract.enterCommittee(
        furtherValidator,
        config.committee.sentinelMembers,
        {
          from: config.committee.consensus,
        },
      );

      await Utils.expectRevert(
        config.committee.contract.enterCommittee(
          validator,
          furtherValidator,
          {
            from: config.committee.consensus,
          },
        ),
        'Validator must be nearer than further away present validator.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should enter only correct validators in the correct order', async () => {
      const metachainId = Utils.generateRandomMetachainId();
      const committeeSize = 50;
      const consensus = accountProvider.get();
      const dislocation = web3.utils.sha3('dislocation1');
      const proposal = web3.utils.sha3('proposal1');
      const numberOfValidators = 299;

      const committee = await CommitteeUtils.createCommittee(
        metachainId,
        consensus,
        committeeSize,
        dislocation,
        proposal,
        {
          from: accountProvider.get(),
        },
      );

      // calculate off-chain all distances for all validators to the proposal
      const sentinelMembers = await committee.SENTINEL_MEMBERS.call();
      const sentinelDistance = await committee.SENTINEL_DISTANCE.call();

      const v = {
        distance: sentinelDistance,
        address: sentinelMembers,
      };

      const dist = [v];
      for (let i = 1; i < numberOfValidators; i += 1) {
        const account = accountProvider.get();
        dist.push({
          distance: CommitteeUtils.distanceToProposal(dislocation, account, proposal),
          address: account,
        });
      }
      dist.sort(compare);

      // enter the closest validators from near to far into the committee
      // each time moving the sentinel outwards
      for (let i = 0; i < committeeSize; i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await committee.enterCommittee(
          dist[i].address,
          sentinelMembers,
          {
            from: consensus,
          },
        );
      }

      await CommitteeUtils.assertCommitteeMembers(
        committee,
        dist.slice(0, committeeSize),
      );
    });

    it('should enter corrects validators in reverse order', async () => {
      const metachainId = Utils.generateRandomMetachainId();
      const committeeSize = 50;
      const consensus = accountProvider.get();
      const dislocation = web3.utils.sha3('dislocation2');
      const proposal = web3.utils.sha3('proposal2');
      const numberOfValidators = 299;

      const committee = await CommitteeUtils.createCommittee(
        metachainId,
        consensus,
        committeeSize,
        dislocation,
        proposal,
        {
          from: accountProvider.get(),
        },
      );

      // calculate off-chain all distances for all validators to the proposal
      const sentinelMembers = await committee.SENTINEL_MEMBERS.call();
      const sentinelDistance = await committee.SENTINEL_DISTANCE.call();

      const v = {
        distance: sentinelDistance,
        address: sentinelMembers,
      };
      const dist = [v];
      for (let i = 1; i < numberOfValidators; i += 1) {
        const account = accountProvider.get();
        dist.push({
          distance: CommitteeUtils.distanceToProposal(dislocation, account, proposal),
          address: account,
        });
      }
      dist.sort(compare);

      // enter correct validators but in reverse order,
      // so committee contract must re-order them
      for (let i = 0; i < committeeSize; i += 1) {
      // eslint-disable-next-line no-await-in-loop
        await committee.enterCommittee(
          dist[committeeSize - i - 1].address,
          sentinelMembers,
          {
            from: consensus,
          },
        );
      }

      await CommitteeUtils.assertCommitteeMembers(
        committee,
        dist.slice(0, committeeSize),
      );
    });

    it('should enter any validator in random order', async () => {
      const metachainId = Utils.generateRandomMetachainId();
      const committeeSize = 50;
      const consensus = accountProvider.get();
      const dislocation = web3.utils.sha3('dislocation3');
      const proposal = web3.utils.sha3('proposal3');
      const numberOfValidators = 299;

      const committee = await CommitteeUtils.createCommittee(
        metachainId,
        consensus,
        committeeSize,
        dislocation,
        proposal,
        {
          from: accountProvider.get(),
        },
      );

      // calculate off-chain all distances for all validators to the proposal
      const sentinelMembers = await committee.SENTINEL_MEMBERS.call();
      const sentinelDistance = await committee.SENTINEL_DISTANCE.call();

      const v = {
        distance: sentinelDistance,
        address: sentinelMembers,
      };
      const dist = [v];
      for (let i = 1; i < numberOfValidators; i += 1) {
        const account = accountProvider.get();
        dist.push({
          distance: CommitteeUtils.distanceToProposal(dislocation, account, proposal),
          address: account,
        });
      }

      // enter all validators, regardless of whether they belong in the committee
      // and let the committee sort them;
      // this approaches worst-case gas consumption because we always use sentinel
      // as furthest member
      for (let i = 1; i < numberOfValidators; i += 1) {
      // eslint-disable-next-line no-await-in-loop
        await committee.enterCommittee(
          dist[i].address,
          sentinelMembers,
          {
            from: consensus,
          },
        );
      }

      dist.sort(compare);

      await CommitteeUtils.assertCommitteeMembers(
        committee,
        dist.slice(0, committeeSize),
      );
    });
  });
});
