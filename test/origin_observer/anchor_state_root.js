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

const { AccountProvider } = require('../test_lib/utils.js');

let originObserver;
let config = {};


contract('OriginObserver::anchorStateRoot', (accounts) => { 
  const accountProvider = new AccountProvider(accounts);
  beforeEach(async () => {
    config = {
      genesisBlockNumber: await Utils.getBlockNumber(),
      genesisStateRoot: Utils.getRandomHash(),
      genesisMaxStateRootLimitCount: new BN(100),
      coconsensus: accountProvider.get(),
    };

    originObserver = await OriginObserver.new();
    await originObserver.setGenesisStorageVariables(
      config.genesisBlockNumber,
      config.genesisStateRoot,
      config.genesisMaxStateRootLimitCount,
    );

    await originObserver.setCoconsensus(config.coconsensus);
    await originObserver.setup();
  });

  contract('Negative Tests', () => {
    it('should fail when the caller is not coconsensus address', async () => {
      const stateRoot = Utils.getRandomHash();
      const blockNumber = await Utils.getBlockNumber();

      await Utils.expectRevert(
        originObserver.anchorStateRoot(
          blockNumber,
          stateRoot,
          { from: accountProvider.get() },
        ),
        'Only the Coconsensus contract can call this function.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should anchor state root', async () => {
      const stateRoot = Utils.getRandomHash();
      const blockNumber = await Utils.getBlockNumber();

      const response = await originObserver.anchorStateRoot(
        blockNumber,
        stateRoot,
        { from: config.coconsensus },
      );

      assert.isOk(
        response.receipt.logs.length > 0,
        'Must emit event',
      );

      const eventObject = response.receipt.logs[0];

      assert.strictEqual(
        eventObject.event,
        'StateRootAvailable',
        'Must emit StateRootAvailable event',
      );

      assert.strictEqual(
        eventObject.args._stateRoot,
        stateRoot,
        'State root from the event is not equal to expected value.',
      );

      assert.strictEqual(
        eventObject.args._blockNumber.eq(blockNumber),
        true,
        `Block number from event ${eventObject.args._blockNumber.toString(10)} must be equal to expected value ${blockNumber}.`,
      );
    });
  });
});
