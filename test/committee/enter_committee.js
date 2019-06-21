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
const web3 = require('../test_lib/web3.js');
const CommitteeUtils = require('./utils.js');

function compare(a, b) {
    return a.distance - b.distance;
};

contract('Committee:enter', async (accounts) => {
  let committeeSize = 50;
  let committeeSizeBN = new BN(committeeSize);
  let numberOfValidators = 999;
  let consensus = accounts[0];
  
  it('should enter only correct validators in the correct order', async () => {
    let dislocation = web3.utils.sha3('dislocation1');
    let proposal = web3.utils.sha3('proposal1');

    const committee = await CommitteeUtils.createCommittee(
      committeeSizeBN,
      dislocation,
      proposal,
      {
        from: consensus,
      },
    );
    
    // calculate off-chain all distances for all validators to the proposal
    let sentinelMembers = await committee.SENTINEL_MEMBERS.call();
    let sentinelDistance = await committee.SENTINEL_DISTANCE.call();

    let v = {
      distance: sentinelDistance,
      address: sentinelMembers,
    };
    let dist = [v];
    for (let i = 1; i < numberOfValidators; i++) {
      let v = {
        distance: CommitteeUtils.distanceToProposal(dislocation, accounts[i], proposal),
        address: accounts[i],
      };
      dist.push(v);
    }
    dist.sort(compare);

    // enter the closest validators from near to far into the committee
    // each time moving the sentinel outwards
    for (let i = 0; i < committeeSize; i++) {  
      await committee.enterCommittee(
        dist[i].address,
        sentinelMembers,
        {
          from: consensus,
        },
      );
    };

    // assert all members in the committee match the distance ordered validators
    for (let i = 0; i < committeeSize-1; i++) {
      // get the next further member in the committee
      // note: the linked-list refers to the closer member
      let member = await committee.members.call(dist[i + 1].address);
      assert.strictEqual(
        member,
        dist[i].address,
        `Member ${i} is ${dist[i].address}, but was expected to be ${member}`,
      );
    };

    // assert we've reached the end of the linked-list
    let member = await committee.members.call(sentinelMembers);
    assert.strictEqual(
      member,
      dist[committeeSize - 1].address,
      `The furthest member ${dist[committeeSize - 1].address} should be ` +
        `given by Sentinel but instead ${member} was returned.`,
    );
  });

  it('should enter corrects validators in random order', async () => {
    let dislocation = web3.utils.sha3('dislocation3');
    let proposal = web3.utils.sha3('proposal3');

    const committee = await CommitteeUtils.createCommittee(
      committeeSizeBN,
      dislocation,
      proposal,
      {
        from: consensus,
      },
    );
    
    // calculate off-chain all distances for all validators to the proposal
    let sentinelMembers = await committee.SENTINEL_MEMBERS.call();
    let sentinelDistance = await committee.SENTINEL_DISTANCE.call();

    let v = {
      distance: sentinelDistance,
      address: sentinelMembers,
    };
    let dist = [v];
    for (let i = 1; i < numberOfValidators; i++) {
      let v = {
        distance: CommitteeUtils.distanceToProposal(dislocation, accounts[i], proposal),
        address: accounts[i],
      };
      dist.push(v);
    }
    dist.sort(compare);

    // enter correct validators but in reverse order,
    // so committee contract must re-order them
    for (let i = 0; i < committeeSize; i++) {  
        await committee.enterCommittee(
            dist[committeeSize - i - 1].address,
            sentinelMembers,
            {
              from: consensus,
            },
        );
    };

    // assert all members in the committee match the distance ordered validators
    for (let i = 0; i < committeeSize-1; i++) {
      // get the next further member in the committee
      // note: the linked-list refers to the closer member
      let member = await committee.members.call(dist[i + 1].address);
      assert.strictEqual(
        member,
        dist[i].address,
        `Member ${i} is ${dist[i].address}, but was expected to be ${member}`,
      );
    };

    // assert we've reached the end of the linked-list
    let member = await committee.members.call(sentinelMembers);
    assert.strictEqual(
      member,
      dist[committeeSize - 1].address,
      `The furthest member ${dist[committeeSize - 1].address} should be ` +
        `given by Sentinel but instead ${member} was returned.`,
    );
  });

  it.skip('should enter any validator in random order', async () => {
    let dislocation = web3.utils.sha3('dislocation3');
    let proposal = web3.utils.sha3('proposal3');

    const committee = await CommitteeUtils.createCommittee(
      committeeSizeBN,
      dislocation,
      proposal,
      {
        from: consensus,
      },
    );
    
    // calculate off-chain all distances for all validators to the proposal
    let sentinelMembers = await committee.SENTINEL_MEMBERS.call();
    let sentinelDistance = await committee.SENTINEL_DISTANCE.call();

    let v = {
      distance: sentinelDistance,
      address: sentinelMembers,
    };
    let dist = [v];
    for (let i = 1; i < numberOfValidators; i++) {
      let v = {
        distance: CommitteeUtils.distanceToProposal(dislocation, accounts[i], proposal),
        address: accounts[i],
      };
      dist.push(v);
    }
    dist.sort(compare);

    // enter all validators, regardless of whether they belong in the committee
    // and let the committee sort them;
    // this approaches worst-case gas consumption because we always use sentinel
    // as furthest member
    for (let i = 1; i < numberOfValidators; i++) {  
      await committee.enterCommittee(
        accounts[i],
        sentinelMembers,
        {
          from: consensus,
        },
      );
    };

    // // note: only the correct closest member should remain in the ordered-linked list
    // // excluded members must have been popped from the members list.

    // // assert all members in the committee match the distance ordered validators
    // for (let i = 0; i < committeeSize-1; i++) {
    //   // get the next further member in the committee
    //   // note: the linked-list refers to the closer member
    //   let member = await committee.members.call(dist[i + 1].address);
    //   assert.strictEqual(
    //     member,
    //     dist[i].address,
    //     `Member ${i} is ${dist[i].address}, but was expected to be ${member}`,
    //   );
    // };

    // // assert we've reached the end of the linked-list
    // let member = await committee.members.call(sentinelMembers);
    // assert.strictEqual(
    //   member,
    //   dist[committeeSize - 1].address,
    //   `The furthest member ${dist[committeeSize - 1].address} should be ` +
    //     `given by Sentinel but instead ${member} was returned.`,
    // );
  });
});