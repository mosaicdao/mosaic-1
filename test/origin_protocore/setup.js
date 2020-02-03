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

const OriginProtocore = artifacts.require('TestOriginProtocore');

const config = {};

contract('OriginProtocore::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.genesis = {};
    config.genesis.originParentVoteMessageHash = Utils.getRandomHash();
    config.genesis.originSourceBlockHash = Utils.ZERO_BYTES32;
    config.genesis.originSourceBlockNumber = new BN(0);
    config.genesis.originTargetBlockHash = Utils.getRandomHash();
    config.genesis.originMetachainId = Utils.getRandomHash();
    config.genesis.domainSeparator = Utils.getRandomHash();
    config.genesis.epochLength = new BN(100);
    config.genesis.metablockHeight = new BN(Utils.getRandomNumber(1000));
    config.genesis.selfProtocore = accountProvider.get();

    config.setupParams = {};
    config.setupParams.coconsensus = accountProvider.get();

    config.genesis.originTargetBlockNumber = new BN(
      Utils.getRandomNumber(10000) * config.genesis.epochLength,
    );

    config.contracts = {};

    // Deploy the origin protocore contract.
    config.contracts.originProtocore = await OriginProtocore.new();

    // Set the value of genesis variables
    await config.contracts.originProtocore.setGenesisStorage(
      config.genesis.originMetachainId,
      config.genesis.domainSeparator,
      config.genesis.epochLength,
      config.genesis.metablockHeight,
      config.genesis.selfProtocore,
      config.genesis.originParentVoteMessageHash,
      config.genesis.originSourceBlockHash,
      config.genesis.originSourceBlockNumber,
      config.genesis.originTargetBlockHash,
      config.genesis.originTargetBlockNumber,
    );

    // Set coconsensus contract address
    await config.contracts.originProtocore.setCoconsensus(config.setupParams.coconsensus);
  });

  contract('Negative Tests', async () => {
    it('should revert if caller is not coconsensus', async () => {
      await Utils.expectRevert(
        config.contracts.originProtocore.setup(
          { from: accountProvider.get() },
        ),
        'Only the Coconsensus contract can call this function.',
      );
    });

    it('should revert if setup is already called once', async () => {
      await config.contracts.originProtocore.setup(
        { from: config.setupParams.coconsensus },
      );
      await Utils.expectRevert(
        config.contracts.originProtocore.setup(
          { from: config.setupParams.coconsensus },
        ),
        'Contract is already initialized.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should initialize the contract successfully', async () => {
      const { originProtocore } = config.contracts;

      await originProtocore.setup(
        { from: config.setupParams.coconsensus },
      );

      const selfProtocoreAddress = await originProtocore.selfProtocore.call();
      assert.strictEqual(
        selfProtocoreAddress,
        config.genesis.selfProtocore,
        'Self protocore address is not set during the setup.',
      );

      const epochLength = await originProtocore.epochLength.call();
      assert.strictEqual(
        epochLength.eq(config.genesis.epochLength),
        true,
        `Epoch length in contract ${epochLength.toString(10)} must be`
        + `equal to ${config.genesis.epochLength.toString(10)}}.`,
      );

      const genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
        config.genesis.domainSeparator,
        Utils.ZERO_BYTES32,
        Utils.ZERO_BYTES32,
        config.genesis.originTargetBlockHash,
        new BN(0),
        config.genesis.originTargetBlockNumber,
      );

      const genesisLink = await originProtocore.links(genesisVoteMessageHash);

      assert.strictEqual(
        genesisLink.parentVoteMessageHash,
        config.genesis.originParentVoteMessageHash,
        'Parent vote message hash is not set in the contract.',
      );
      assert.strictEqual(
        genesisLink.targetBlockHash,
        config.genesis.originTargetBlockHash,
        'Origin target block hash is not set in the contract.',
      );
      assert.strictEqual(
        genesisLink.targetBlockNumber.eq(config.genesis.originTargetBlockNumber),
        true,
        `Origin target block number from contract ${genesisLink.targetBlockNumber.toString(10)} `
        + `must be equal to expected value ${config.genesis.originTargetBlockNumber.toString(10)}.`,
      );
      assert.strictEqual(
        genesisLink.sourceTransitionHash,
        Utils.ZERO_BYTES32,
        'Source transition hash in genesis link must be null.',
      );
      assert.strictEqual(
        genesisLink.proposedMetablockHeight.eq(config.genesis.metablockHeight),
        true,
        `Proposed metablock height from contract ${genesisLink.proposedMetablockHeight.toString(10)} `
        + `must be equal to ${config.genesis.metablockHeight.toString(10)}.`,
      );
      assert.strictEqual(
        genesisLink.forwardVoteCount.eqn(0),
        true,
        'Forward vote count in genesis link must be zero.',
      );
      assert.strictEqual(
        genesisLink.forwardVoteCountNextHeight.eqn(0),
        true,
        'Forward vote count next height in genesis link must be zero.',
      );
      assert.strictEqual(
        genesisLink.forwardVoteCountPreviousHeight.eqn(0),
        true,
        'Forward vote count previous height in genesis link must be zero.',
      );
      assert.strictEqual(
        genesisLink.targetFinalisation.eqn(ProtocoreUtils.CheckpointFinalisationStatus.Finalised),
        true,
        'Target finalization status must be Finalized',
      );
    });
  });
});
