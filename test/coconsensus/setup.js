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

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const Coconsensus = artifacts.require('CoconsensusTest');
const OriginObserver = artifacts.require('OriginObserverTest');
const SelfProtocore = artifacts.require('TestSelfProtocore');

const config = {};

// Function to do set the genesis data for protocore contracts.
async function setProtocoreGenesisStorageData() {
  const genesis = {};
  genesis.auxiliaryParentVoteMessageHash = Utils.getRandomHash();
  genesis.auxiliarySourceTransitionHash = Utils.getRandomHash();
  genesis.auxiliarySourceBlockHash = Utils.getRandomHash();
  genesis.auxiliaryTargetBlockHash = Utils.getRandomHash();
  genesis.auxiliaryAccumulatedGas = new BN(1000000);
  genesis.auxiliaryMetachainId = Utils.getRandomHash();
  genesis.domainSeparator = Utils.getRandomHash();
  genesis.dynasty = new BN(0);
  genesis.epochLength = new BN(100);
  genesis.metablockHeight = new BN(Utils.getRandomNumber(1000));
  genesis.auxiliarySourceBlockNumber = new BN(
    Utils.getRandomNumber(10000) * genesis.epochLength,
  );
  genesis.auxiliaryTargetBlockNumber = genesis.auxiliarySourceBlockNumber
    .add(genesis.epochLength);

  const protocore = await SelfProtocore.new();

  await protocore.setGenesisStorage(
    genesis.auxiliaryMetachainId,
    genesis.domainSeparator,
    genesis.epochLength,
    genesis.metablockHeight,
    genesis.dynasty,
    genesis.auxiliaryParentVoteMessageHash,
    genesis.auxiliarySourceTransitionHash,
    genesis.auxiliarySourceBlockHash,
    genesis.auxiliarySourceBlockNumber,
    genesis.auxiliaryTargetBlockHash,
    genesis.auxiliaryTargetBlockNumber,
    genesis.auxiliaryAccumulatedGas,
  );

  await protocore.setCoconsensus(config.contracts.coconsensus.address);

  return {
    genesisProtocoreData: genesis,
    protocore,
  };
}

// Function to set origin observer contract genesis data.
async function setOriginObserverGenesisStorageData() {
  const genesis = {};
  genesis.originBlockNumber = await Utils.getBlockNumber();
  genesis.originStateRoot = Utils.getRandomHash();
  genesis.maxStateRootLimitCount = new BN(100);

  const originObserver = await OriginObserver.new();

  await originObserver.setGenesisStorageVariables(
    genesis.originBlockNumber,
    genesis.originStateRoot,
    genesis.maxStateRootLimitCount,
  );

  await originObserver.setCoconsensus(config.contracts.coconsensus.address);

  return {
    genesisOriginObserverData: genesis,
    originObserver,
  };
}

contract('Coconsensus::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {

    // Setup params/
    config.setupParams = {};
    config.setupParams.coconsensus = accountProvider.get();

    // Contract addresses.
    config.contracts = {};
    config.contracts.coconsensus = await Coconsensus.new();

    // Genesis data for coconsensus contract.
    config.genesis = {};
    config.genesis.metachainIds = [];
    config.genesis.observers = [];
    config.genesis.protocores = [];
    config.genesis.protocoreData = {};
    config.genesis.observerData = {};

    // eslint-disable-next-line prefer-destructuring
    config.genesis.originMetachainId = config.genesis.metachainIds[0];

    // eslint-disable-next-line prefer-destructuring
    config.genesis.auxiliaryMetachainId = config.genesis.metachainIds[1];

    /* eslint-disable no-await-in-loop */
    for (let i = 0; i < 5; i += 1) {
      const {
        genesisProtocoreData,
        protocore,
      } = await setProtocoreGenesisStorageData();

      const metachainId = genesisProtocoreData.auxiliaryMetachainId;
      config.genesis.metachainIds.push(metachainId);
      config.genesis.protocores.push(protocore.address);
      config.genesis.protocoreData[metachainId] = genesisProtocoreData;

      const {
        genesisOriginObserverData,
        originObserver,
      } = await setOriginObserverGenesisStorageData();

      config.genesis.observers.push(originObserver.address);
      config.genesis.observerData[metachainId] = genesisOriginObserverData;
    }

    await config.contracts.coconsensus.setGenesisStorage(
      config.genesis.metachainIds,
      config.genesis.protocores,
      config.genesis.observers,
    );
  });

  contract('Negative Tests', async () => {
    it('should fail when setup is called more than once', async () => {
      // Call setup function.
      await config.contracts.coconsensus.setup();

      await Utils.expectRevert(
        config.contracts.coconsensus.setup(),
        'Coconsensus contract is already initialized.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should initialize the coconsensus contract', async () => {
      const { coconsensus } = config.contracts;

      // Call setup function.
      await coconsensus.setup();

      for (let index = 0; index < config.genesis.metachainIds.length; index += 1) {
        const metachainId = config.genesis.metachainIds[index];

        const protocoreAddress = await coconsensus.protocores(metachainId);
        assert.strictEqual(
          protocoreAddress,
          config.genesis.protocores[index],
          'Protocore address is not set.',
        );

        const observersAddress = await coconsensus.observers(metachainId);
        assert.strictEqual(
          observersAddress,
          config.genesis.observers[index],
          'Observer address is not set.',
        );

        const domainSeparator = await coconsensus.domainSeparators(metachainId);
        assert.strictEqual(
          domainSeparator,
          config.genesis.protocoreData[metachainId].domainSeparator,
          'Domain separator is not set.',
        );

        const blockTips = await coconsensus.blockTips(metachainId);

        const expectedTip = config
          .genesis
          .protocoreData[metachainId]
          .auxiliaryTargetBlockNumber;

        assert.strictEqual(
          blockTips.eq(expectedTip),
          true,
          'Block tip is not set.',
        );

        const blockchains = await coconsensus.blockchains(metachainId, blockTips);
        assert.strictEqual(
          blockchains.blockHash,
          config.genesis.protocoreData[metachainId].auxiliaryTargetBlockHash,
          'Blockhash is not set.',
        );

        const expectedDynasty = config
          .genesis
          .protocoreData[metachainId]
          .metablockHeight;

        assert.strictEqual(
          blockchains.statusDynasty.eq(expectedDynasty),
          true,
          'Dynasty is not set.',
        );
      }
    });
  });
});
