// Copyright 2020 OpenST Ltd.
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

const OriginObserver = artifacts.require('OriginObserverTest');

const Utils = require('../test_lib/utils.js');

let originObserver;
let config = {};

contract('OriginObserver::setup', () => {
  beforeEach(async () => {
    config = {
      genesisBlockNumber: await Utils.getBlockNumber(),
      genesisStateRoot: Utils.getRandomHash(),
      genesisMaxStateRootLimitCount: new BN(100),
    };

    originObserver = await OriginObserver.new();
    await originObserver.setGenesisStorageVariables(
      config.genesisBlockNumber,
      config.genesisStateRoot,
      config.genesisMaxStateRootLimitCount,
    );
  });

  contract('Positive Tests', () => {
    it('should anchor state root', async () => {
      await originObserver.setup();

      const latestStateRootBlockNumber = await originObserver.getLatestStateRootBlockNumber();
      const stateRoot = await originObserver.getStateRoot(latestStateRootBlockNumber);

      assert.strictEqual(
        latestStateRootBlockNumber.eq(config.genesisBlockNumber),
        true,
        `Latest block number from contract ${latestStateRootBlockNumber.toString(10)}`
        + `must be equal to ${config.genesisBlockNumber.toString(10)}`,
      );

      assert.strictEqual(
        stateRoot,
        config.genesisStateRoot,
        'Latest state root must be equal to genesis state root.',
      );
    });
  });
});
