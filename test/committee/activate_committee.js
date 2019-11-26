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
const web3 = require('../test_lib/web3.js');

const CommitteeUtils = require('./utils.js');

let config = {};

contract('Committee::activateCommittee', async (accounts) => {
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

    const dist = CommitteeUtils.getCommitteeMembers(
      accountProvider,
      config.committee.dislocation,
      config.committee.proposal,
      config.committee.size,
      CommitteeUtils.compareMemberDistance,
    );

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
    it('should fail if a caller is not a member', async () => {
      await Utils.expectRevert(
        config.committee.contract.activateCommittee(
          {
            from: accountProvider.get(),
          },
        ),
        'Only members can call this function.',
      );
    });

    it('should fail if committee is in open phase status', async () => {
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

      const member = accountProvider.get();
      await committee.enterCommittee(
        member,
        sentinelMembers,
        {
          from: consensus,
        },
      );

      const status = await committee.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isCommitteeOpen(status),
        'Committee status is not open upon creation.',
      );

      await Utils.expectRevert(
        committee.activateCommittee(
          {
            from: member,
          },
        ),
        'Committee formation must be cooling down.',
      );
    });

    it('should fail if committee is in commit phase status', async () => {
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
        'Committee status is not in commit phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.activateCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be cooling down.',
      );
    });

    it('should fail if committee is in invalid phase status', async () => {
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
        'Committee status is not in commit phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.activateCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be cooling down.',
      );
    });

    it('should fail if committee is in reveal phase status', async () => {
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
        'Committee status is not in reveal phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.activateCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be cooling down.',
      );
    });

    it('should fail if committee is in closed state', async () => {
      await config.committee.contract.setCommitteeStatusToClosed();
      const status = await config.committee.contract.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isClosed(status),
        'Committee status is not in invalid phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.activateCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must be cooling down.',
      );
    });

    it('should fail if committee activation block height is not reached', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );
      await Utils.expectRevert(
        config.committee.contract.activateCommittee(
          {
            from: config.committee.member,
          },
        ),
        'Committee formation must have cooled down before activation.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('Checks storage state after successfull activation', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );
      await CommitteeUtils.passActivationBlockHeight(
        config.committee.contract,
      );

      await config.committee.contract.activateCommittee(
        {
          from: config.committee.member,
        },
      );

      const committeeContract = config.committee.contract;

      const committeeStatus = await committeeContract.committeeStatus.call();

      assert.isOk(
        CommitteeUtils.isInCommitPhase(committeeStatus),
      );

      const commitTimeOutBlockHeight = await committeeContract.commitTimeOutBlockHeight.call();

      const commitPhaseTimeout = await committeeContract.COMMITTEE_COMMIT_PHASE_TIMEOUT.call();
      const currentBlock = await web3.eth.getBlockNumber();

      assert.isOk(
        commitTimeOutBlockHeight.eq(commitPhaseTimeout.iadd(new BN(currentBlock))),
      );
    });
  });
});
