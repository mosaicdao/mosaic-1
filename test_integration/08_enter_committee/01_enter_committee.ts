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

import shared from '../shared';
import Interacts from '../../interacts/Interacts';
import Utils from '../Utils';

import chai = require('chai');
const { assert } = chai;
const BN = require('bn.js');

describe('Committee::enterCommittee', async () => {
  const { web3 } = shared.origin;

  async function validatorDistance(validators, dislocation, proposal, committeeDistance) {
    const dist = [];
    for (let i = 0; i < validators.length; i++) {
      dist.push({
        address: validators[i].address,
        distance: new BN(await committeeDistance.methods.distanceToProposal(validators[i].address).call()),
      });
    }
    dist.sort(compareMemberDistance);
    return dist;
  }

  function compareMemberDistance(firstMember, secondMember) {
    return firstMember.distance.cmp(secondMember.distance);
  }

  it('Enters committee', async () => {
    const consensusInstance = shared.origin.contracts.Consensus.instance;
    const SENTINEL_ADDRESS = await consensusInstance.methods.SENTINEL_COMMITTEES().call();
    const committeeAddress = await consensusInstance.methods.committees(SENTINEL_ADDRESS).call();
    const committeeInstance = Interacts.getCommittee(web3, committeeAddress);

    const sentinelMembers = await committeeInstance.methods.SENTINEL_MEMBERS().call();

    const validators = await validatorDistance(
      shared.origin.keys.validators,
      await committeeInstance.methods.dislocation().call(),
      await committeeInstance.methods.proposal().call(),
      committeeInstance,
    );

    const committeeSize = parseInt(await committeeInstance.methods.committeeSize().call());
    for (let i = 0; i < committeeSize; i++) {
      const rawTx = consensusInstance.methods.enterCommittee(
        committeeAddress,
        validators[i].address,
        sentinelMembers,
      );
      const txOptions = {
        from: validators[i].address,
      };
      await Utils.sendTransaction(rawTx, txOptions);
    }

    const membersCount = parseInt(await committeeInstance.methods.memberCount().call());
    assert.strictEqual(
      membersCount,
      committeeSize,
    );
    console.log(await committeeInstance.methods.getMembers().call());
    // assertion of all members in the committee.
    for (let i = 0; i < membersCount - 1; i += 1) {
    // eslint-disable-next-line no-await-in-loop
      const member = await committeeInstance.methods.members(validators[i + 1].address).call();
      console.log('member :- ', member);
      assert.strictEqual(
        member,
        validators[i].address,
        `Member ${i} is ${validators[i].address}, but was expected to be ${member}`,
      );
    }

    const member = await committeeInstance.methods.members(sentinelMembers).call();

    assert.strictEqual(
      member,
      validators[membersCount - 1].address,
      `The furthest member ${validators[membersCount - 1].address} should be `
          + `given by Sentinel but instead ${member} was returned.`,
    );
  });
});
