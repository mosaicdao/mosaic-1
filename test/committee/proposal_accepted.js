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

const crypto = require('crypto');

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3.js');

const CommitteeUtils = require('./utils.js');

const CommitteeMockConsensus = artifacts.require('CommitteeMockConsensus');

let config = {};

function createCommitteeMember(account, position) {
  const member = {
    address: account,
    position,
    salt: `0x${crypto.randomBytes(32).toString('hex')}`,
  };

  member.sealedCommit = CommitteeUtils.sealCommit(
    position, member.salt, account,
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

contract('Committee::proposalAccepted', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      committee: {
        metachainId: Utils.generateRandomMetachainId(),
        size: 3,
        dislocation: web3.utils.sha3('dislocation'),
        proposal: web3.utils.sha3('proposal'),
        consensus: await CommitteeMockConsensus.new(),
      },
    };

    config.committee.contract = await CommitteeUtils.createCommittee(
      config.committee.metachainId,
      config.committee.consensus.address,
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

    config.committee.members = createCommitteeMembers(
      members,
      config.committee.proposal,
    );

    await CommitteeUtils.enterMembersThruConsensus(
      config.committee.consensus,
      config.committee.contract,
      members,
    );

    await config.committee.contract.cooldownCommittee(
      {
        from: config.committee.members[0].address,
      },
    );

    await CommitteeUtils.passActivationBlockHeight(config.committee.contract);

    await config.committee.contract.activateCommittee(
      {
        from: config.committee.members[0].address,
      },
    );

    await CommitteeUtils.submitSealedCommits(
      config.committee.contract,
      config.committee.members.map(m => m.address),
      config.committee.members.map(m => m.sealedCommit),
    );

    Object.freeze(config);
  });

  contract('Positive Tests', async () => {
    // TODO: committee:committeeDecision is the function to query
    it.skip('checks that proposal is successfully accepted', async () => {
      const committeeContract = config.committee.contract;

      assert.isNotOk(
        await committeeContract.proposalAccepted.call(),
      );

      const member0 = config.committee.members[0];
      await committeeContract.revealCommit(
        member0.position,
        member0.salt,
        {
          from: member0.address,
        },
      );

      assert.isNotOk(
        await committeeContract.proposalAccepted.call(),
      );

      const member1 = config.committee.members[1];
      await committeeContract.revealCommit(
        member1.position,
        member1.salt,
        {
          from: member1.address,
        },
      );

      assert.isOk(
        await committeeContract.proposalAccepted.call(),
      );
    });
  });
});
