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

const ValidatorSet = artifacts.require('ValidatorSetDouble');

contract('ValidatorSet::removeValidator', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let validatorSet;
  const beginHeight = new BN(100);
  const endHeight = new BN(500);
  let account;
  beforeEach(async () => {
    validatorSet = await ValidatorSet.new();
    await validatorSet.setupValidatorSetDouble();
    account = accountProvider.get();
    await validatorSet.insertValidator(account, beginHeight);
  });

  contract('Positive Tests', () => {
    it('should remove validator', async () => {
      await validatorSet.removeValidator(account, endHeight);

      const actualValidatorBeginHeight = await validatorSet.validatorBeginHeight.call(account);
      const actualValidatorEndHeight = await validatorSet.validatorEndHeight.call(account);
      assert.strictEqual(
        beginHeight.eq(actualValidatorBeginHeight),
        true,
        `Expected validator begin height is ${beginHeight} but got ${actualValidatorBeginHeight}`,
      );

      assert.strictEqual(
        endHeight.eq(actualValidatorEndHeight),
        true,
        `Expected validator end height is ${endHeight} `
        + `but got ${actualValidatorEndHeight}`,
      );
    });
  });
});
