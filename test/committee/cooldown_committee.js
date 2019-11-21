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

contract('Committee:cooldownCommittee', async (accounts) => {
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
      config.committee.consensus,
      config.committee.size,
      config.committee.dislocation,
      config.committee.proposal,
      {
        from: accountProvider.get(),
      },
    );

    config.committee.sentinelMembers = await config.committee.contract.SENTINEL_MEMBERS.call();
    config.committee.formationCooldown = (
      await config.committee.contract.COMMITTEE_FORMATION_COOLDOWN.call()
    ).toNumber();

    config.committee.member = accountProvider.get();
    config.committee.contract = await CommitteeUtils.createCommittee(
      config.committee.size,
      config.committee.dislocation,
      config.committee.proposal,
      {
        from: config.committee.consensus,
      },
    );

    const dist = CommitteeUtils.getMemberDistance(
      accountProvider,
      config.committee.dislocation,
      config.committee.proposal,
      config.committee.size,
      CommitteeUtils.compare,
    );

    config.committee.furthestMember = dist[config.committee.size + 1].address;
    config.committee.closestMember = dist[0].address;
    config.committee.member = dist[1].address;

    await CommitteeUtils.enterMembers(
      config.committee.contract,
      dist.slice(1, config.committee.size + 1).map(
        d => d.address,
      ),
      config.committee.consensus,
    );

    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should fail if committee is not filled', async () => {
      const consensus = accountProvider.get();
      const committee = await CommitteeUtils.createCommittee(
        consensus,
        3,
        web3.utils.sha3('dislocation'),
        web3.utils.sha3('proposal'),
        {
          from: accountProvider.get(),
        },
      );

      const sentinelMembers = await config.committee.contract.SENTINEL_MEMBERS.call();

      await committee.enterCommittee(
        accountProvider.get(),
        sentinelMembers,
        {
          from: consensus,
        },
      );

      const memberToInitiateCooldown = accountProvider.get();
      await committee.enterCommittee(
        memberToInitiateCooldown,
        sentinelMembers,
        {
          from: consensus,
        },
      );

      await Utils.expectRevert(
        committee.cooldownCommittee(
          {
            from: memberToInitiateCooldown,
          },
        ),
        'To close committee member count must equal committee size.',
      );
    });

    it('should fail if non-member is calling', async () => {
      await Utils.expectRevert(
        config.committee.contract.cooldownCommittee(
          {
            from: config.committee.consensus,
          },
        ),
        'Only members can call this function.',
      );
    });

    it('should fail if committee is in cooldown state', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );

      await Utils.advanceBlocks(config.committee.formationCooldown + 1);

      await Utils.expectRevert(
        config.committee.contract.cooldownCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be open.',
      );
    });

    it('should fail if committee is in commit state', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );

      await CommitteeUtils.passActivationBlockHeight(config.committee.contract);

      await config.committee.contract.activateCommittee(
        {
          from: config.committee.member,
        },
      );

      const status = await config.committee.contract.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isInCommitPhase(status),
        'Committee status is not is commit phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.cooldownCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be open.',
      );
    });

    it('should fail if committee is in reveal state', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );

      await CommitteeUtils.passActivationBlockHeight(config.committee.contract);

      await config.committee.contract.activateCommittee(
        {
          from: config.committee.member,
        },
      );

      await CommitteeUtils.passCommitTimeoutBlockHeight(config.committee.contract);

      await config.committee.contract.closeCommitPhase({
        from: accountProvider.get(),
      });

      const status = await config.committee.contract.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isInRevealPhase(status),
        'Committee status is not is commit phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.cooldownCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be open.',
      );
    });

    it('should fail if committee is in invalid state', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );

      await CommitteeUtils.passActivationBlockHeight(config.committee.contract);

      await config.committee.contract.challengeCommittee(
        config.committee.closestMember,
        {
          from: config.committee.consensus,
        },
      );

      const status = await config.committee.contract.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isInvalid(status),
        'Committee status is not in invalid phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.cooldownCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be open.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks storage after successful start of cooldown', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );

      // eslint-disable-next-line max-len
      const memberInitiatedCooldown = await config.committee.contract.memberInitiatedCooldown.call();
      assert.strictEqual(
        memberInitiatedCooldown,
        config.committee.member,
        'Member that initiated cooldown does not match.',
      );

      const activationBlockHeight = await config.committee.contract.activationBlockHeight.call();
      const blockNumber = await web3.eth.getBlockNumber();
      assert.isOk(
        activationBlockHeight.eqn(config.committee.formationCooldown + blockNumber),
        'Incorrect activation block height.',
      );

      const status = await config.committee.contract.committeeStatus.call();
      CommitteeUtils.isCoolingDown(status);
    });
  });
});
