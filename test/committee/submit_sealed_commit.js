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
const crypto = require('crypto');

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3.js');

const CommitteeUtils = require('./utils.js');

let config = {};

function createCommitteeMember(account, proposal) {
  const member = {
    address: account,
    salt: `0x${crypto.randomBytes(32).toString('hex')}`,
  };

  member.sealedCommit = CommitteeUtils.sealCommit(
    proposal, member.salt, account,
  );

  return member;
}

contract('Committee::submitSealedCommit', async (accounts) => {
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

    const members = [];
    for (let i = 0; i < config.committee.size; i += 1) {
      members.push(
        accountProvider.get(),
      );
    }

    config.committee.memberA = createCommitteeMember(
      members[0], config.committee.proposal,
    );

    config.committee.memberB = createCommitteeMember(
      members[1], config.committee.proposal,
    );

    config.committee.memberC = createCommitteeMember(
      members[2], config.committee.proposal,
    );

    await CommitteeUtils.enterMembers(
      config.committee.contract,
      members,
      config.committee.consensus,
    );

    await config.committee.contract.cooldownCommittee(
      {
        from: config.committee.memberA.address,
      },
    );

    await CommitteeUtils.passActivationBlockHeight(config.committee.contract);

    await config.committee.contract.activateCommittee(
      {
        from: config.committee.memberB.address,
      },
    );

    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should fail if a caller is not a member', async () => {
      await Utils.expectRevert(
        config.committee.contract.submitSealedCommit(
          crypto.randomBytes(32),
          {
            from: accountProvider.get(),
          },
        ),
        'Only members can call this function.',
      );
    });

    it('should fail if committee is not in commit phase status', async () => {
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

      await Utils.expectRevert(
        committee.submitSealedCommit(
          crypto.randomBytes(32),
          {
            from: member,
          },
        ),
        'Committee must be in the commit phase.',
      );
    });

    it('should fail if sealed commit is zero value', async () => {
      await Utils.expectRevert(
        config.committee.contract.submitSealedCommit(
          Utils.ZERO_BYTES32,
          {
            from: config.committee.memberA.address,
          },
        ),
        'Sealed commit cannot be null.',
      );
    });

    it('should fail if member is committing second time', async () => {
      const sealedCommit1 = crypto.randomBytes(32);
      const sealedCommit2 = crypto.randomBytes(32);

      await config.committee.contract.submitSealedCommit(
        sealedCommit1,
        {
          from: config.committee.memberA.address,
        },
      );

      await Utils.expectRevert(
        config.committee.contract.submitSealedCommit(
          sealedCommit1,
          {
            from: config.committee.memberA.address,
          },
        ),
        'Member can only commit once.',
      );

      await Utils.expectRevert(
        config.committee.contract.submitSealedCommit(
          sealedCommit2,
          {
            from: config.committee.memberA.address,
          },
        ),
        'Member can only commit once.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks storage state after successfull commit', async () => {
      const expectedSealedCommit = crypto.randomBytes(32);

      const expectedSubmissionCount = (
        await config.committee.contract.submissionCount.call()
      ).iadd(new BN(1));

      await config.committee.contract.submitSealedCommit(
        expectedSealedCommit,
        {
          from: config.committee.memberA.address,
        },
      );

      const actualSubmissionCount = await config.committee.contract.submissionCount.call();

      assert.isOk(
        actualSubmissionCount.eq(expectedSubmissionCount),
      );

      const actualSealedCommit = await config.committee.contract.commits.call(
        config.committee.memberA.address,
      );

      assert.strictEqual(
        `0x${expectedSealedCommit.toString('hex')}`,
        actualSealedCommit,
      );
    });

    it('checks that the committee transitions to reveal phase '
     + 'once all members submit sealed commits', async () => {
      const committeeContract = config.committee.contract;

      let status = await committeeContract.committeeStatus.call();
      assert.isNotOk(CommitteeUtils.isInRevealPhase(status));

      await committeeContract.submitSealedCommit(
        config.committee.memberA.sealedCommit,
        {
          from: config.committee.memberA.address,
        },
      );

      status = await committeeContract.committeeStatus.call();
      assert.isNotOk(CommitteeUtils.isInRevealPhase(status));

      await committeeContract.submitSealedCommit(
        config.committee.memberB.sealedCommit,
        {
          from: config.committee.memberB.address,
        },
      );

      status = await committeeContract.committeeStatus.call();
      assert.isNotOk(CommitteeUtils.isInRevealPhase(status));

      await committeeContract.submitSealedCommit(
        config.committee.memberC.sealedCommit,
        {
          from: config.committee.memberC.address,
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

    it('checks that the committee transitions to reveal phase '
     + 'once reveal phase timeout is reached', async () => {
      const committeeContract = config.committee.contract;

      let status = await committeeContract.committeeStatus.call();
      assert.isNotOk(CommitteeUtils.isInRevealPhase(status));

      await CommitteeUtils.passCommitTimeoutBlockHeight(committeeContract);

      await committeeContract.submitSealedCommit(
        config.committee.memberA.sealedCommit,
        {
          from: config.committee.memberA.address,
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
