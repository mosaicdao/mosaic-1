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

contract('Committee::closeCommitPhase', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      committee: {
        size: 3,
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

    const dist = CommitteeUtils.getMemberDistance(
      accountProvider,
      config.committee.dislocation,
      config.committee.proposal,
      config.committee.size,
      CommitteeUtils.compare,
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
    it('should fail if committee is in open phase status', async () => {
      await Utils.expectRevert(
        config.committee.contract.closeCommitPhase(
          {
            from: accountProvider.get(),
          },
        ),
        'Committee must be in the commit phase.',
      );
    });

    it('should fail if committee is in cooldown phase status', async () => {
      await config.committee.contract.cooldownCommittee(
        {
          from: config.committee.member,
        },
      );

      const status = await config.committee.contract.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isCoolingDown(status),
        'Committee status is not in cooling down phase.',
      );

      await Utils.expectRevert(
        config.committee.contract.closeCommitPhase(
          {
            from: accountProvider.get(),
          },
        ),
        'Committee must be in the commit phase.',
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
        config.committee.contract.closeCommitPhase(
          {
            from: accountProvider.get(),
          },
        ),
        'Committee must be in the commit phase.',
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
        config.committee.contract.closeCommitPhase(
          {
            from: accountProvider.get(),
          },
        ),
        'Committee must be in the commit phase.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks that committee closes commit phase '
     + 'if the commit phase timeout has been reached', async () => {
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

      const committeeContract = config.committee.contract;

      let status = await committeeContract.committeeStatus.call();
      assert.isNotOk(CommitteeUtils.isInRevealPhase(status));

      await committeeContract.closeCommitPhase(
        {
          from: accountProvider.get(),
        },
      );

      status = await committeeContract.committeeStatus.call();
      assert.isNotOk(CommitteeUtils.isInRevealPhase(status));

      await CommitteeUtils.passCommitTimeoutBlockHeight(committeeContract);

      await committeeContract.closeCommitPhase(
        {
          from: accountProvider.get(),
        },
      );

      status = await committeeContract.committeeStatus.call();
      assert.isOk(CommitteeUtils.isInRevealPhase(status));

      const revealTimeOutBlockHeight = await committeeContract.revealTimeOutBlockHeight.call();
      const revealPhaseTimeout = await committeeContract.COMMITTEE_REVEAL_PHASE_TIMEOUT.call();
      const currentBlock = await web3.eth.getBlockNumber();

      assert.isOk(
        revealTimeOutBlockHeight.eq(revealPhaseTimeout.iadd(new BN(currentBlock))),
      );
    });
  });
});
