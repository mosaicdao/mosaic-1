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
require('../test_lib/web3.js');
const CoreUtils = require('./utils.js');

let config = {};

// TASK: improve constructor to constrain inputs
// TASK: complete tests

contract('Core::constructor', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      chainId: Utils.NULL_ADDRESS,
      epochLength: new BN(100),
      minValidators: new BN(3),
      joinLimit: new BN(5),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(0),
      dynasty: new BN(0),
      accumulatedGas: new BN(0),
      source: Utils.ZERO_BYTES32,
      sourceBlockHeight: new BN(0),
      consensus: accountProvider.get(),
      reputation: accountProvider.get(),
    };
    Object.freeze(config);
  });

  contract('Positive Tests', () => {
    it('should construct', async () => {
      const core = await CoreUtils.createCore(
        config.chainId,
        config.epochLength,
        config.minValidators,
        config.joinLimit,
        config.reputation,
        config.height,
        config.parent,
        config.gasTarget,
        config.dynasty,
        config.accumulatedGas,
        config.source,
        config.sourceBlockHeight,
        {
          from: config.consensus,
        },
      );

      const consensus = await core.consensus.call();
      assert.strictEqual(
        consensus === config.consensus,
        true,
        `Consensus contract is set to ${consensus} and is not ${config.consensus}.`,
      );
    });
  });
});
