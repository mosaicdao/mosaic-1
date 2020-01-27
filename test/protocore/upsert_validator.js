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

const TestProtocore = artifacts.require('TestProtocore');

const config = {};
const validator = {};

contract('Protocore::upsertValidator', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.coconsensusAddress = accountProvider.get();

    config.epochLength = new BN(100);

    config.genesisKernelHeight = new BN(1);
    config.genesisKernelHash = Utils.getRandomHash();

    config.core = accountProvider.get();

    config.genesisParentVoteMessageHash = Utils.getRandomHash();
    config.metachainId = Utils.getRandomHash();
    config.genesisSourceTransitionHash = Utils.getRandomHash();
    config.genesisSourceBlockHash = Utils.getRandomHash();
    config.genesisTargetBlockHash = Utils.getRandomHash();
    config.genesisSourceBlockNumber = new BN(0);
    config.genesisTargetBlockNumber = new BN(config.epochLength);
    config.genesisProposedMetablockHeight = new BN(1);

    config.protocore = await TestProtocore.new(
      config.coconsensusAddress,
      config.core,
      config.metachainId,
      config.epochLength,
      config.genesisKernelHeight,
      config.genesisKernelHash,
      config.genesisParentVoteMessageHash,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
      config.genesisProposedMetablockHeight,
      config.genesisParentVoteMessageHash,
    );

    validator.address = accountProvider.get();
    validator.beginHeight = new BN(20);
    validator.endHeight = new BN(100);
    validator.reputation = new BN(500);

    await config.protocore.setup();
  });


  contract('Positive Tests', async () => {
    it('should insert new validator if already not present', async () => {
      await config.protocore.upsertValidator(
        validator.address,
        validator.beginHeight,
        validator.reputation,
        {
          from: config.coconsensusAddress,
        },
      );

      assert.notStrictEqual(
        await config.protocore.validators.call(validator.address),
        Utils.NULL_ADDRESS,
      );
    });

    it('should remove validator if reputation is 0', async () => {
      await config.protocore.upsertValidator(
        validator.address,
        validator.beginHeight,
        validator.reputation,
        {
          from: config.coconsensusAddress,
        },
      );

      const actualValidatorEndHeight = await config.protocore.validatorEndHeight.call(
        validator.address,
      );

      assert.strictEqual(
        actualValidatorEndHeight.eq(Utils.MAX_UINT256),
        true,
        `Expected validator end height is ${Utils.MAX_UINT256} but got ${actualValidatorEndHeight}`,
      );

      await config.protocore.upsertValidator(
        validator.address,
        validator.endHeight,
        '0',
        {
          from: config.coconsensusAddress,
        },
      );

      const actualValidatorEndHeightAfterRemoval = await config.protocore.validatorEndHeight.call(
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
