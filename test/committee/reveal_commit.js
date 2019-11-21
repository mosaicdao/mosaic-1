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

function createCommitteeMember(account, position) {
  const member = {
    address: account,
    position,
    salt: `0x${crypto.randomBytes(32).toString('hex')}`,
  };

  member.sealedCommit = CommitteeUtils.sealCommit(
    position, member.salt,
  );

  return member;
}

function createCommitteeMembers(accounts, position) {
  const members = [];
  for (let i = 0; i < accounts.length; i += 1) {
    members.push(createCommitteeMember(accounts[i], position));
  }

  return members;
}

async function checkCommitteeStorage(
  committee,
  expected,
) {
  // checking positions

  assert.isOk(
    expected.positions !== undefined,
  );
  assert.isOk(
    Array.isArray(expected.positions),
  );

  expected.positions.forEach(
    async ({ address, position }) => {
      assert.isOk(address !== undefined);
      assert.isOk(position !== undefined);

      const actualPosition = await committee.positions.call(
        address,
      );

      assert.strictEqual(
        actualPosition,
        position,
      );
    },
  );


  // checking positionCounts

  assert.isOk(
    expected.positionCounts !== undefined,
  );
  assert.isOk(
    Array.isArray(expected.positionCounts),
  );

  expected.positionCounts.forEach(
    async ({ position, count }) => {
      assert.isOk(position !== undefined);
      assert.isOk(count !== undefined);

      const actualPositionCount = await committee.positionCounts.call(
        position,
      );

      assert.isOk(
        actualPositionCount.eq(new BN(count)),
      );
    },
  );


  // checking positionsTaken

  assert.isOk(
    expected.positionsTaken !== undefined,
  );
  assert.isOk(
    Array.isArray(expected.positionsTaken),
  );

  expected.positionsTaken.forEach(
    async ({ index, position }) => {
      assert.isOk(index !== undefined);
      assert.isOk(position !== undefined);

      const actualPosition = await committee.positionsTaken.call(index);

      assert.strictEqual(
        actualPosition,
        position,
      );
    },
  );


  // checking committeeDecision

  const committeeDecision = await committee.committeeDecision.call();

  assert.isOk(
    expected.committeeDecision !== undefined,
  );

  assert.strictEqual(
    committeeDecision,
    expected.committeeDecision,
  );


  // checking totalPositionsCount

  const totalPositionsCount = await committee.totalPositionsCount.call();

  assert.isOk(
    expected.totalPositionsCount !== undefined,
  );

  assert.isOk(
    totalPositionsCount.eq(new BN(expected.totalPositionsCount)),
  );
}

contract('Committee::revealCommit', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let members = [];
  beforeEach(async () => {
    members = [];
    config = {
      committee: {
        size: 7,
        dislocation: web3.utils.sha3('dislocation'),
        positionA: web3.utils.sha3('positionA'),
        positionB: web3.utils.sha3('positionB'),
        consensus: accountProvider.get(),
      },
    };

    config.committee.proposal = config.committee.positionA;

    config.committee.contract = await CommitteeUtils.createCommittee(
      config.committee.size,
      config.committee.dislocation,
      config.committee.proposal,
      {
        from: config.committee.consensus,
      },
    );

    config.committee.sentinelMembers = await config.committee.contract.SENTINEL_MEMBERS.call();
    config.committee.quorum = await config.committee.contract.quorum.call();

    for (let i = 0; i < config.committee.size; i += 1) {
      members.push(
        accountProvider.get(),
      );
    }

    // Member committed a vote on zero position.
    config.committee.member0 = createCommitteeMember(
      members[0],
      Utils.ZERO_BYTES32,
    );

    // Members committed their votes on the positionA.
    config.committee.membersA = createCommitteeMembers(
      members.slice(1, 5),
      config.committee.positionA,
    );

    // Members committed their votes on the positionB.
    config.committee.membersB = createCommitteeMembers(
      members.slice(5),
      config.committee.positionB,
    );

    assert.isOk(
      members.length * config.committee.membersA.length / config.committee.membersB.length
      > config.committee.quorum,
    );

    await CommitteeUtils.enterMembers(
      config.committee.contract,
      members,
      config.committee.consensus,
    );

    await config.committee.contract.cooldownCommittee(
      {
        from: config.committee.membersA[0].address,
      },
    );

    await CommitteeUtils.passActivationBlockHeight(config.committee.contract);

    await config.committee.contract.activateCommittee(
      {
        from: config.committee.membersA[0].address,
      },
    );

    config.committee.submitSealedCommits = async () => {
      await CommitteeUtils.submitSealedCommits(
        config.committee.contract,
        [config.committee.member0.address],
        [config.committee.member0.sealedCommit],
      );

      await CommitteeUtils.submitSealedCommits(
        config.committee.contract,
        config.committee.membersA.map(m => m.address),
        config.committee.membersA.map(m => m.sealedCommit),
      );

      await CommitteeUtils.submitSealedCommits(
        config.committee.contract,
        config.committee.membersB.map(m => m.address),
        config.committee.membersB.map(m => m.sealedCommit),
      );
    };

    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should fail if a caller is not a member', async () => {
      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          crypto.randomBytes(32),
          crypto.randomBytes(32),
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
        3,
        web3.utils.sha3('dislocation'),
        web3.utils.sha3('proposal'),
        {
          from: consensus,
        },
      );

      await CommitteeUtils.enterMembers(
        committee,
        members,
        consensus,
      );

      const status = await committee.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isCommitteeOpen(status),
        'Committee status is not open upon creation.',
      );

      const member = config.committee.membersA[0];
      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          member.salt,
          {
            from: member.address,
          },
        ),
        'Committee must be in the reveal phase.',
      );
    });

    it('should fail if committee is in cool down phase status', async () => {
      const consensus = accountProvider.get();
      const committee = await CommitteeUtils.createCommittee(
        3,
        web3.utils.sha3('dislocation'),
        web3.utils.sha3('proposal'),
        {
          from: consensus,
        },
      );

      await CommitteeUtils.enterMembers(
        committee,
        members,
        consensus,
      );

      await committee.cooldownCommittee(
        {
          from: members[0],
        },
      );

      const status = await committee.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isCoolingDown(status),
        'Committee status is not is cooling down phase.',
      );

      const member = config.committee.membersA[0];
      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          member.salt,
          {
            from: member.address,
          },
        ),
        'Committee must be in the reveal phase.',
      );
    });

    it('should fail if committee is in commit phase status', async () => {
      const status = await config.committee.contract.committeeStatus.call();
      assert.isOk(
        CommitteeUtils.isInCommitPhase(status),
        'Committee status is not open upon creation.',
      );
      const member = config.committee.membersA[0];
      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          member.salt,
          {
            from: member.address,
          },
        ),
        'Committee must be in the reveal phase.',
      );
    });

    it('should fail if a member has not submitted a commit', async () => {
      await CommitteeUtils.passCommitTimeoutBlockHeight(config.committee.contract);
      await config.committee.contract.closeCommitPhase();

      const member = config.committee.membersA[0];
      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          member.salt,
          {
            from: member.address,
          },
        ),
        'Commit cannot be null.',
      );
    });

    it('should fail if a member submitted and already revealed its commit', async () => {
      const member = config.committee.membersA[0];
      await config.committee.contract.submitSealedCommit(
        member.sealedCommit,
        {
          from: member.address,
        },
      );

      await CommitteeUtils.passCommitTimeoutBlockHeight(config.committee.contract);
      await config.committee.contract.closeCommitPhase();

      await config.committee.contract.revealCommit(
        member.position,
        member.salt,
        {
          from: member.address,
        },
      );

      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          member.salt,
          {
            from: member.address,
          },
        ),
        'Commit cannot be null.',
      );
    });

    it('should fail if a member submitted a sealed commit on position 0', async () => {
      const member = config.committee.member0;
      await config.committee.contract.submitSealedCommit(
        member.sealedCommit,
        {
          from: member.address,
        },
      );

      await CommitteeUtils.passCommitTimeoutBlockHeight(config.committee.contract);
      await config.committee.contract.closeCommitPhase();
      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          member.salt,
          {
            from: member.address,
          },
        ),
        'Position cannot be null.',
      );
    });

    it('should fail if a member reveals position and salt that '
     + 'does not match to sealed commit', async () => {
      const member = config.committee.membersA[0];
      await config.committee.contract.submitSealedCommit(
        member.sealedCommit,
        {
          from: member.address,
        },
      );

      await CommitteeUtils.passCommitTimeoutBlockHeight(config.committee.contract);
      await config.committee.contract.closeCommitPhase();

      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          crypto.randomBytes(32),
          member.salt,
          {
            from: member.address,
          },
        ),
        'Position must match previously submitted commit.',
      );

      await Utils.expectRevert(
        config.committee.contract.revealCommit(
          member.position,
          crypto.randomBytes(32),
          {
            from: member.address,
          },
        ),
        'Position must match previously submitted commit.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks storage after successfully revealing commits of two members '
    + 'on the same position', async () => {
      const committeeContract = config.committee.contract;

      await config.committee.submitSealedCommits();

      const member1 = config.committee.membersA[0];
      await committeeContract.revealCommit(
        member1.position,
        member1.salt,
        {
          from: member1.address,
        },
      );

      await checkCommitteeStorage(
        committeeContract,
        {
          positions: [
            { address: member1.address, position: member1.position },
          ],
          positionCounts: [
            { position: member1.position, count: 1 },
          ],
          positionsTaken: [
            { index: 0, position: member1.position },
          ],
          committeeDecision: Utils.ZERO_BYTES32,
          totalPositionsCount: 1,
        },
      );

      const member2 = config.committee.membersA[1];
      await committeeContract.revealCommit(
        member2.position,
        member2.salt,
        {
          from: member2.address,
        },
      );

      await checkCommitteeStorage(
        committeeContract,
        {
          positions: [
            { address: member1.address, position: member1.position },
            { address: member2.address, position: member2.position },
          ],
          positionCounts: [
            { position: member1.position, count: 2 },
          ],
          positionsTaken: [
            { index: 0, position: member1.position },
          ],
          committeeDecision: Utils.ZERO_BYTES32,
          totalPositionsCount: 2,
        },
      );
    });

    it('checks storage after successfully revealing commits of two members '
    + 'on the different positions', async () => {
      const committeeContract = config.committee.contract;

      await config.committee.submitSealedCommits();

      const memberA = config.committee.membersA[0];
      await committeeContract.revealCommit(
        memberA.position,
        memberA.salt,
        {
          from: memberA.address,
        },
      );

      await checkCommitteeStorage(
        committeeContract,
        {
          positions: [
            { address: memberA.address, position: memberA.position },
          ],
          positionCounts: [
            { position: memberA.position, count: 1 },
          ],
          positionsTaken: [
            { index: 0, position: memberA.position },
          ],
          committeeDecision: Utils.ZERO_BYTES32,
          totalPositionsCount: 1,
        },
      );

      const memberB = config.committee.membersB[0];
      await committeeContract.revealCommit(
        memberB.position,
        memberB.salt,
        {
          from: memberB.address,
        },
      );

      await checkCommitteeStorage(
        committeeContract,
        {
          positions: [
            { address: memberA.address, position: memberA.position },
            { address: memberB.address, position: memberB.position },
          ],
          positionCounts: [
            { position: memberA.position, count: 1 },
            { position: memberB.position, count: 1 },
          ],
          positionsTaken: [
            { index: 0, position: memberA.position },
            { index: 1, position: memberB.position },
          ],
          committeeDecision: Utils.ZERO_BYTES32,
          totalPositionsCount: 2,
        },
      );
    });

    it('checks that committee reached a decision', async () => {
      const committeeContract = config.committee.contract;

      await config.committee.submitSealedCommits();

      await CommitteeUtils.revealCommits(
        committeeContract,
        config.committee.membersA.map(m => m.address),
        config.committee.membersA.map(m => ({ position: m.position, salt: m.salt })),
      );

      await CommitteeUtils.revealCommits(
        committeeContract,
        config.committee.membersB.map(m => m.address),
        config.committee.membersB.map(m => ({ position: m.position, salt: m.salt })),
      );

      await checkCommitteeStorage(
        committeeContract,
        {
          positions: [].concat(
            config.committee.membersA.map(
              m => ({ address: m.address, position: config.committee.positionA }),
            ),
            config.committee.membersB.map(
              m => ({ address: m.address, position: config.committee.positionB }),
            ),
          ),
          positionCounts: [
            {
              position: config.committee.positionA,
              count: config.committee.membersA.length,
            },
            {
              position: config.committee.positionB,
              count: config.committee.membersB.length,
            },
          ],
          positionsTaken: [
            { index: 0, position: config.committee.positionA },
            { index: 1, position: config.committee.positionB },
          ],
          committeeDecision: config.committee.positionA,
          totalPositionsCount: config.committee.membersA.length + config.committee.membersB.length,
        },
      );
    });
  });
});
