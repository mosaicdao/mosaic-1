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

contract('ValidatorSet::insertValidator', (accounts) => {
  beforeEach(async () => {
    config.activeHeight = new BN(1);
    config.validatorSet = await ValidatorSet.new();
    await config.validatorSet.setupValidatorSetDouble(config.activeHeight);
  });

  contract('Positive Tests', () => {
    const accountProvider = new AccountProvider(accounts);

    it('should insert validators', async () => {
      const beginHeight = config.activeHeight;
      const v = accountProvider.get();

      await config.validatorSet.insertValidator(v, beginHeight);

      const actualValidatorBeginHeight = await config.validatorSet.validatorBeginHeight.call(v);
      const actualValidatorEndHeight = await config.validatorSet.validatorEndHeight.call(v);

      assert.isOk(
        beginHeight.eq(actualValidatorBeginHeight),
        `Expected validator begin height is ${beginHeight} but got ${actualValidatorBeginHeight}`,
      );

      assert.isOk(
        actualValidatorEndHeight.eq(Utils.MAX_UINT256),
        `Expected validator end height is ${Utils.MAX_UINT256} `
         + `but got ${actualValidatorEndHeight}`,
      );

      const nextValidatorInLinkedList = await config.validatorSet.validators.call(v);

      // Checking that the validator exists in the linked list of validators
      // by querying the next validator (pointed by the validator) and asserting
      // that its not NULL (it should be either sentinel or another validator address).
      assert.notStrictEqual(
        nextValidatorInLinkedList,
        Utils.NULL_ADDRESS,
        'The next validator address in the linked list of validators pointed by the v1 is null.',
      );
    });
  });
});
