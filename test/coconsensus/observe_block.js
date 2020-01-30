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

const CoconsensusUtils = require('./utils');

contract('Coconsensus::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  const config = {};
  config.observeBlockParam = {};
  config.observeBlockParam.rlpBlockHeader = '0xf901f9a083cafc574e1f51ba9dc0568fc617a08ea2429fb384059c972f13b19fa1c8dd55a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347948888f1f195afa192cfee860698584c030f4c9db1a0ef1552a40b7165c3cd773806b9e0c165b75356e0314bf0706f279c729f51e018a05fe50b260da6308036625b850b5d6ced6d0a9f814c0688bc91ffb7b7a3a54b67a0bc37d79753ad738a6dac4921e57392f145d8887476de3f783dfa7edae9283e52b9010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000830200000a832fefd8825208845506eb0780a0bd4472abb6659ebe3ee06ee4d7b72a00a9f4d001caca51342001075469aff49888a13a5a8c8f2bb1c4';
  config.observeBlockParam.blockHash = '0xccfa807576d1718924e23c58d0237b25b582942a593034dfff1fef59f2f110db';
  config.observeBlockParam.stateRoot = '0xef1552a40b7165c3cd773806b9e0c165b75356e0314bf0706f279c729f51e018';
  config.observeBlockParam.blockNumber = new BN(10);

  beforeEach(async () => {
    const { deployCoconsensus } = CoconsensusUtils;
    Object.assign(config, await deployCoconsensus(accountProvider));
  });

  contract('Negative Tests', async () => {
    it('should revert when called more than once with same params', async () => {
      const {
        selfProtocore,
        coconsensus,
      } = config.contracts;

      const { metachainIds } = config.genesis;
      const originMetachainId = metachainIds[0];

      // Set the current dynasty in the self protocore.
      let currentDynasty = 2;
      await selfProtocore.setCurrentDynasty(currentDynasty);

      // Finalize the checkpoint.
      await coconsensus.setFinaliseCheckpoint(
        originMetachainId,
        config.observeBlockParam.blockNumber,
        config.observeBlockParam.blockHash,
        currentDynasty,
      );

      // Increament the dynasty.
      currentDynasty = 3;
      await selfProtocore.setCurrentDynasty(currentDynasty);

      await coconsensus.observeBlock(
        originMetachainId,
        config.observeBlockParam.rlpBlockHeader,
      );

      await Utils.expectRevert(
        coconsensus.observeBlock(
          originMetachainId,
          config.observeBlockParam.rlpBlockHeader,
        ),
        'Given block number is lower or equal to highest anchored state root block number.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should observe block by anchoring the state root in the origin observer contract', async () => {
      const {
        selfProtocore,
        originObserver,
        coconsensus,
      } = config.contracts;

      const { metachainIds } = config.genesis;
      const originMetachainId = metachainIds[0];

      // Set the current dynasty in the self protocore.
      let currentDynasty = 2;
      await selfProtocore.setCurrentDynasty(currentDynasty);

      // Finalize the checkpoint.
      await coconsensus.setFinaliseCheckpoint(
        originMetachainId,
        config.observeBlockParam.blockNumber,
        config.observeBlockParam.blockHash,
        currentDynasty,
      );

      // Increament the dynasty.
      currentDynasty = 3;
      await selfProtocore.setCurrentDynasty(currentDynasty);

      await coconsensus.observeBlock(
        originMetachainId,
        config.observeBlockParam.rlpBlockHeader,
      );

      const anchoredBlockNumber = await originObserver.getLatestStateRootBlockNumber();
      assert.strictEqual(
        anchoredBlockNumber.eq(config.observeBlockParam.blockNumber),
        true,
        `Anchored block number ${anchoredBlockNumber.toString(10)} must be `
        + `equal to expected ${config.observeBlockParam.blockNumber.toString(10)} value.`,
      );

      const anchoredStateRoot = await originObserver.getStateRoot(anchoredBlockNumber);
      assert.strictEqual(
        anchoredStateRoot,
        config.observeBlockParam.stateRoot,
        'Incorrect state root anchored in the contract.',
      );
    });
  });
});
