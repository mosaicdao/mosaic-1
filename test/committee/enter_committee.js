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
    return a - b;
};

contract('Committee:enter', (accounts) => {
  let committeeSize = new BN(50);
  let dislocation = web3.utils.sha3('dislocation');
  let proposal = web3.utils.sha3('proposal');
  let numberOfValidators = 999;
  
  it('should enter validators in the correct order', async() => {
    const committee = await CommitteeUtils.createCommittee(
      committeeSize,
      dislocation,
      proposal,
    );
    
    // calculate off-chain all distances for all validators to the proposal
    let dist = [await committee.SENTINEL_DISTANCE.call()];
    console.log(dist[0]);

    for (let i = 1; i < numberOfValidators; i++) {
      dist.push(CommitteeUtils.distanceToProposal(dislocation, accounts[i], proposal))
    }
    dist.sort(compare);
    console.log(dist[997]);
  });


//   it('should enter validators in order')
//   for (let i = 1; i < numberOfValidators; i++) {
//     await committee
//   };

});