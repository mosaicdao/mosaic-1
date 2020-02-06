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

const ValidatorSet = artifacts.require('ValidatorSetDouble');

const config = {};

contract('ValidatorSet::removeValidatorInternal', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.activeHeight = new BN(1);
    config.validatorSet = await ValidatorSet.new();
    config.validatorSet.setupValidatorSetDouble(config.activeHeight);
    config.validator = {
      address: accountProvider.get(),
      beginHeight: config.activeHeight,
    };
    await config.validatorSet.insertValidator(
      config.validator.address, config.validator.beginHeight,
    );
  });

  contract('Positive Tests', () => {
    it('should remove validator', async () => {
      // Making sure validator is active.
      let validatorActualEndHeight = await config.validatorSet.validatorEndHeight.call(
        config.validator.address,
      );
      assert.isOk(validatorActualEndHeight.eq(Utils.MAX_UINT256));

      const endHeight = config.activeHeight.addn(1);

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);

      await config.validatorSet.removeValidator(config.validator.address, endHeight);

      validatorActualEndHeight = await config.validatorSet.validatorEndHeight.call(
        config.validator.address,
      );
      assert.isOk(
        endHeight.eq(validatorActualEndHeight),
        `Expected validator end height is ${endHeight} but got ${validatorActualEndHeight}`,
      );
    });
  });
});
