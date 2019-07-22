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


contract('Committee::distance', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  const config = {
    consensus: accountProvider.get(),
    committeeSize: new BN(10),
    dislocation: web3.utils.sha3('dislocation'),
    proposal: web3.utils.sha3('proposal'),
  };
  Object.freeze(config);

  it('should calculate the same distance as .js', async () => {
    const committee = await CommitteeUtils.createCommittee(
      config.committeeSize,
      config.dislocation,
      config.proposal,
    );

    {
      const account = accountProvider.get();
      const distanceAccount = await committee.distanceToProposal.call(account);
      const calculatedDistanceAccount = CommitteeUtils.distanceToProposal(
        config.dislocation, account, config.proposal,
      );

      assert.strictEqual(
        calculatedDistanceAccount.eq(distanceAccount),
        true,
        `Calculated distance (${calculatedDistanceAccount}) does not match `
        + `distance from Committee (${distanceAccount})`,
      );
    }

    {
      const account = Utils.NULL_ADDRESS;
      const distanceAccount = await committee.distanceToProposal.call(account);
      const calculatedDistanceAccount = CommitteeUtils.distanceToProposal(
        config.dislocation, account, config.proposal,
      );

      assert.strictEqual(
        calculatedDistanceAccount.eq(distanceAccount),
        true,
        `Calculated distance (${calculatedDistanceAccount}) does not match `
        + `distance from Committee (${distanceAccount})`,
      );
    }
  });
});
