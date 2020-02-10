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

const config = {};

async function assertValidatorSetCount(validatorSet, height, count) {
  const actualCount = await validatorSet.validatorSetCount(height);
  assert.isOk(
    actualCount.eq(count),
  );
}

contract('ValidatorSet::validatorSetCount', (accounts) => {
  beforeEach(async () => {
    config.activeHeight = new BN(1);
    config.validatorSet = await ValidatorSet.new();
    await config.validatorSet.setupValidatorSetDouble(config.activeHeight);
  });

  contract('Positive Tests', () => {
    const accountProvider = new AccountProvider(accounts);

    it('checks validator set count', async () => {
      const v0 = accountProvider.get();
      const v1 = accountProvider.get();
      const v2 = accountProvider.get();

      const height0 = config.activeHeight.clone();
      await config.validatorSet.insertValidator(v0, height0);

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);
      const height1 = config.activeHeight.clone();
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));

      await config.validatorSet.insertValidator(v1, height1);
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));

      await config.validatorSet.insertValidator(v2, height1);
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);
      const height2 = config.activeHeight.clone();
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));

      await config.validatorSet.removeValidator(v2, height2);
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);
      const height3 = config.activeHeight.clone();
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height2, new BN(3));

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);
      const height4 = config.activeHeight.clone();
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height2, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height3, new BN(2));

      await config.validatorSet.removeValidator(v1, height4);
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height2, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height3, new BN(2));

      await config.validatorSet.removeValidator(v0, height4);
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height2, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height3, new BN(2));

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);
      const height5 = config.activeHeight.clone();
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height2, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height3, new BN(2));
      await assertValidatorSetCount(config.validatorSet, height4, new BN(2));

      config.activeHeight.iaddn(1);
      await config.validatorSet.incrementActiveHeight(config.activeHeight);
      await assertValidatorSetCount(config.validatorSet, height0, new BN(1));
      await assertValidatorSetCount(config.validatorSet, height1, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height2, new BN(3));
      await assertValidatorSetCount(config.validatorSet, height3, new BN(2));
      await assertValidatorSetCount(config.validatorSet, height4, new BN(2));
      await assertValidatorSetCount(config.validatorSet, height5, new BN(0));
    });
  });
});
