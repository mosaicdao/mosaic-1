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

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3.js');

const CoreUtils = require('./utils.js');

let config = {};

contract('Core::constructor', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      chainId: Utils.NULL_ADDRESS,
      epochLength: 100,
      height: 0,
      parent: Utils.ZERO_BYTES32,
      gasTarget: 0,
      dynasty: 0,
      accumulatedGas: 0,
      source: Utils.ZERO_BYTES32,
      sourceBlockHeight: 0,
      consensus: accountProvider.get(),
    };
    Object.freeze(config);
  });

  contract('Positive Tests', () => {
    it('should construct', async () => {
      const core = await CoreUtils.createCore(
        config.chainId,
        config.epochLength,
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