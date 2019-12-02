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

  let web3 = shared.origin.web3;

  function validatorDistance(validators, dislocation, proposal) {
    const dist = [];
       for(let i = 0; i< validators.length; i++ ) {
    dist.push({
      address: validators[i],
      distance: distanceToProposal(
        dislocation,
        validators[i],
        proposal,
      ),
    });
  }
  dist.sort(compareMemberDistance);
  return dist;

  }

  function compareMemberDistance(firstMember, secondMember) {
  return firstMember.distance.cmp(secondMember.distance);
}

  function shuffleAccount(dislocation, account) {
  return web3.utils.soliditySha3(
    { t: 'address', v: account },
    { t: 'bytes32', v: dislocation },
  );
}

function remove0x(str) {
  if (str.substr(0, 2) === '0x') {
    return str.substr(2);
  }

  return str;
}

function distance(h1, h2) {
  // Create BN from hashes.
  const a = new BN(remove0x(h1), 16);
  const b = new BN(remove0x(h2), 16);

  // Return XOR as big number.
  return a.xor(b);
}

function distanceToProposal(dislocation, account, proposal) {
  return distance(shuffleAccount(dislocation, account), proposal);
}

  it('Forms committee', async () => {

    const axiom = shared.origin.contracts.Axiom;
    const consensusInstance = shared.origin.contracts.Consensus.instance;
    const SENTINEL_ADDRESS = await consensusInstance.methods.SENTINEL_COMMITTEES().call();
    const committeeAddress = await consensusInstance.methods.committees(SENTINEL_ADDRESS).call();
    const committeeInstance = Interacts.getCommittee(committeeAddress);
    const validatorAddress = '';
    const validators = validatorDistance(
      shared.origin.keys.validators,
      await committeeInstance.methods.dislocation().call(),
      await committeeInstance.methods.proposal().call(),
    );
    const furtherAddress = validators[validators.length - 1];
    const committeeSize = parseInt(await committeeInstance.methods.committeeSize().call());
    for(let i = 0; i < committeeSize; i++) {
      const rawTx = consensusInstance.methods.enterCommittee(
      committeeAddress,
      validatorAddress[i],
      furtherAddress,
    );
      const txOptions = {
      from: validatorAddress[i],
    };
     await Utils.sendTransaction(rawTx, txOptions);
    }

    const membersCount = parseInt(await committeeInstance.methods.memberCount().call());

  assert.strictEqual(
    membersCount,
    committeeSize,
  );

  // assertion of all members in the committee.
  for (let i = 0; i < membersCount - 1; i += 1) {

    // eslint-disable-next-line no-await-in-loop
    const member = await committeeInstance.methods.members(validators[i + 1].address).call();
    assert.strictEqual(
      member,
      validators[i].address,
      `Member ${i} is ${validators[i].address}, but was expected to be ${member}`,
    );
  }

  });

});
