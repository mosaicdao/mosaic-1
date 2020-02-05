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
const ProtocoreUtils = require('../protocore/utils');
const Utils = require('../test_lib/utils.js');

const SelfProtocore = artifacts.require('TestSelfProtocore');

const config = {};

contract('SelfProtocore::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.genesis = {};
    config.genesis.auxiliaryParentVoteMessageHash = Utils.getRandomHash();
    config.genesis.auxiliarySourceTransitionHash = Utils.getRandomHash();
    config.genesis.auxiliarySourceBlockHash = Utils.getRandomHash();
    config.genesis.auxiliaryTargetBlockHash = Utils.getRandomHash();
    config.genesis.auxiliaryAccumulatedGas = new BN(1000000);
    config.genesis.auxiliaryMetachainId = Utils.getRandomHash();
    config.genesis.domainSeparator = Utils.getRandomHash();
    config.genesis.epochLength = new BN(100);
    config.genesis.dynasty = new BN(0);
    config.genesis.metablockHeight = new BN(Utils.getRandomNumber(1000));

    config.setupParams = {};

    config.setupParams.coconsensus = accountProvider.get();

    config.genesis.auxiliarySourceBlockNumber = new BN(
      Utils.getRandomNumber(10000) * config.genesis.epochLength,
    );
    config.genesis.auxiliaryTargetBlockNumber = config.genesis.auxiliarySourceBlockNumber
      .add(config.genesis.epochLength);

    config.contracts = {};

    // Deploy the self protocore contract.
    config.contracts.selfProtocore = await SelfProtocore.new();

    // Set the value of genesis variables
    await config.contracts.selfProtocore.setGenesisStorage(
      config.genesis.auxiliaryMetachainId,
      config.genesis.domainSeparator,
      config.genesis.epochLength,
      config.genesis.dynasty,
      config.genesis.metablockHeight,
      config.genesis.auxiliaryParentVoteMessageHash,
      config.genesis.auxiliarySourceTransitionHash,
      config.genesis.auxiliarySourceBlockHash,
      config.genesis.auxiliarySourceBlockNumber,
      config.genesis.auxiliaryTargetBlockHash,
      config.genesis.auxiliaryTargetBlockNumber,
      config.genesis.auxiliaryAccumulatedGas,
    );

    // Set coconsensus contract address
    await config.contracts.selfProtocore.setCoconsensus(config.setupParams.coconsensus);
  });

  contract('Negative Tests', async () => {
    it('should revert if caller is not coconsensus', async () => {
      await Utils.expectRevert(
        config.contracts.selfProtocore.setup(
          { from: accountProvider.get() },
        ),
        'Only the Coconsensus contract can call this function.',
      );
    });

    it('should revert if setup is already called once', async () => {
      await config.contracts.selfProtocore.setup(
        { from: config.setupParams.coconsensus },
      );
      await Utils.expectRevert(
        config.contracts.selfProtocore.setup(
          { from: config.setupParams.coconsensus },
        ),
        'Contract is already initialized.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should initialize the contract successfully', async () => {
      const { selfProtocore } = config.contracts;

      await selfProtocore.setup(
        { from: config.setupParams.coconsensus },
      );

      const epochLength = await selfProtocore.epochLength.call();
      assert.strictEqual(
        epochLength.eq(config.genesis.epochLength),
        true,
        `Epoch length in contract ${epochLength.toString(10)} must be`
        + `equal to ${config.genesis.epochLength.toString(10)}}.`,
      );

      const genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
        config.genesis.domainSeparator,
        config.genesis.auxiliarySourceTransitionHash,
        config.genesis.auxiliarySourceBlockHash,
        config.genesis.auxiliaryTargetBlockHash,
        config.genesis.auxiliarySourceBlockNumber,
        config.genesis.auxiliaryTargetBlockNumber,
      );

      const genesisLink = await selfProtocore.links(genesisVoteMessageHash);

      assert.strictEqual(
        genesisLink.parentVoteMessageHash,
        config.genesis.auxiliaryParentVoteMessageHash,
        'Parent vote message hash is not set in the contract.',
      );
      assert.strictEqual(
        genesisLink.targetBlockHash,
        config.genesis.auxiliaryTargetBlockHash,
        'Auxiliary target block hash is not set in the contract.',
      );
      assert.strictEqual(
        genesisLink.targetBlockNumber.eq(config.genesis.auxiliaryTargetBlockNumber),
        true,
        `Auxiliary target block number from contract ${genesisLink.targetBlockNumber.toString(10)} `
        + `must be equal to expected value ${config.genesis.auxiliaryTargetBlockNumber.toString(10)}.`,
      );
      assert.strictEqual(
        genesisLink.sourceTransitionHash,
        config.genesis.auxiliarySourceTransitionHash,
        `Source transition hash in genesis link must be ${config.genesis.auxiliarySourceTransitionHash}.`,
      );
      assert.strictEqual(
        genesisLink.proposedMetablockHeight.eq(config.genesis.metablockHeight),
        true,
        `Proposed metablock height from contract ${genesisLink.proposedMetablockHeight.toString(10)} `
        + `must be equal to ${config.genesis.metablockHeight.toString(10)}.`,
      );
      assert.isOk(
        (await selfProtocore.fvsVoteCount(
          genesisVoteMessageHash,
          config.genesis.metablockHeight,
        )).eqn(0),
      );
      assert.strictEqual(
        genesisLink.targetFinalisation.eqn(ProtocoreUtils.CheckpointFinalisationStatus.Finalised),
        true,
        'Target finalization status must be Finalized',
      );
    });
  });
});
