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

contract('ValidatorSet::insertValidator', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let validatorSet;
  const beginHeight = new BN(100);
  beforeEach(async () => {
    validatorSet = await ValidatorSet.new();
  });

  contract('Positive Tests', () => {
    it('should insert validators', async () => {
      const account1 = accountProvider.get();
      const account2 = accountProvider.get();

      await validatorSet.insertValidator(account1, beginHeight);

      const actualValidatorBeginHeight = await validatorSet.validatorBeginHeight.call(account1);
      const actualValidatorEndHeight = await validatorSet.validatorEndHeight.call(account1);
      assert.isOk(
        beginHeight.eq(actualValidatorBeginHeight),
        `Expected validator begin height is ${beginHeight} but got ${actualValidatorBeginHeight}`,
      );

      assert.isOk(
        actualValidatorEndHeight.eq(Utils.MAX_UINT256),
        `Expected validator end height is ${Utils.MAX_UINT256} `
         + `but got ${actualValidatorEndHeight}`,
      );

      // Inserting another validator.
      await validatorSet.insertValidator(account2, beginHeight);

      const actualValidatorAtSentinelAddress = await validatorSet.validators.call(
        Utils.SENTINEL_ADDRESS,
      );

      assert.strictEqual(
        actualValidatorAtSentinelAddress,
        account2,
        'Incorrect validator address at sentinel address',
      );

      const expectedValidatorLinkedToAccount2 = await validatorSet.validators.call(account2);

      assert.strictEqual(
        expectedValidatorLinkedToAccount2,
        account1,
        'Incorrectly linked linked-list',
      );
    });
  });
});
