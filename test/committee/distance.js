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

contract('Committee::distance', (accounts) => {
  let committeeSize = new BN(10);
  let dislocation = web3.utils.sha3('dislocation');
  let proposal = web3.utils.sha3('proposal');

  it('should calculate the same distance as .js', async () => {
    const committee = await CommitteeUtils.createCommittee(
      committeeSize,
      dislocation,
      proposal,
    );

    const distanceAccount = await committee.distanceToProposal.call(accounts[0]);
    const calculatedDistanceAccount = CommitteeUtils.distanceToProposal(dislocation, accounts[0], proposal);
    assert.strictEqual(
      calculatedDistanceAccount.eq(distanceAccount),
      true,
      `Calculated distance (${calculatedDistanceAccount}) does not match distance from Committee (${distanceAccount})`
    );
  });
});