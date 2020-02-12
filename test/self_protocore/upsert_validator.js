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

const TestSelfProtocore = artifacts.require('TestSelfProtocore');

const config = {};
const validator = {};

contract('SelfProtocore::upsertValidator', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.coconsensusAddress = accountProvider.get();

    config.epochLength = new BN(100);

    config.genesisKernelHeight = new BN(1);
    config.genesisKernelHash = Utils.getRandomHash();

    config.core = accountProvider.get();
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
    config.genesis.auxiliarySourceBlockNumber = new BN(
      Utils.getRandomNumber(10000) * config.genesis.epochLength,
    );
    config.genesis.auxiliaryTargetBlockNumber = config.genesis.auxiliarySourceBlockNumber
      .add(config.genesis.epochLength);

    config.setupParams = {};
    config.setupParams.coconsensus = accountProvider.get();

    // Deploy the self protocore contract.
    config.selfProtocore = await TestSelfProtocore.new();

    await config.selfProtocore.setGenesisStorage(
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
    config.openKernelHeight = new BN(20);
    validator.address = accountProvider.get();
    validator.beginHeight = config.openKernelHeight.addn(1);
    validator.endHeight = new BN(100);
    validator.reputation = new BN(500);

    await config.selfProtocore.setCoconsensus(config.coconsensusAddress);
    await config.selfProtocore.setOpenKernelHeight(config.openKernelHeight);

    await config.selfProtocore.setup(
      {
        from: config.coconsensusAddress,
      },
    );
  });

  contract('Positive Tests', async () => {
    it('should insert new validator if already not present', async () => {
      await config.selfProtocore.upsertValidator(
        validator.address,
        validator.beginHeight,
        validator.reputation,
        {
          from: config.coconsensusAddress,
        },
      );

      assert.notStrictEqual(
        await config.selfProtocore.validators.call(validator.address),
        Utils.NULL_ADDRESS,
        'Expected address is SENTINEL_ADDRESS(0x1)',
      );
    });

    it.skip('should remove validator if reputation is 0', async () => {
      await config.selfProtocore.upsertValidator(
        validator.address,
        validator.beginHeight,
        validator.reputation,
        {
          from: config.coconsensusAddress,
        },
      );
      const actualValidatorEndHeight = await config.selfProtocore.validatorEndHeight.call(
        validator.address,
      );

      assert.strictEqual(
        actualValidatorEndHeight.eq(Utils.MAX_UINT256),
        true,
        `Expected validator end height is ${Utils.MAX_UINT256} but got ${actualValidatorEndHeight}`,
      );

      config.openKernelHeight = validator.endHeight.subn(1);
      await config.selfProtocore.setOpenKernelHeight(config.openKernelHeight);
      await config.selfProtocore.upsertValidator(
        validator.address,
        validator.endHeight,
        new BN(0),
        {
          from: config.coconsensusAddress,
        },
      );

      const actualValidatorEndHeightAfterRemoval = await config.selfProtocore.validatorEndHeight.call(
        validator.address,
      );
      assert.strictEqual(
        actualValidatorEndHeightAfterRemoval.eq(validator.endHeight),
        true,
        `Expected validator end height is ${validator.endHeight} but got `
         + `${actualValidatorEndHeightAfterRemoval}`,
      );
    });
  });
});
