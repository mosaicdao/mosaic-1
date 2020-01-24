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

const Coreputation = artifacts.require('CoreputationTest');

contract('Coreputation::upsertValidator', (accounts) => {
  let accountProvider;
  let coreputationInstance;
  let inputValidatorInfo;
  let coconsensus;
  const ValidatorStatus = {
    Undefined: 0,
    Slashed: 1,
    Staked: 2,
    Deregistered: 3,
  };

  beforeEach(async () => {
    accountProvider = new AccountProvider(accounts);
    coconsensus = accountProvider.get();
    coreputationInstance = await Coreputation.new(coconsensus);
    inputValidatorInfo = {
      validator: accountProvider.get(),
      reputation: new BN('10'),
    };
  });

  it('should add validator in Staked state when reputation is non-zero', async () => {
    await coreputationInstance.upsertValidator(
      inputValidatorInfo.validator,
      inputValidatorInfo.reputation,
      { from: coconsensus },
    );
    const insertedValidator = await coreputationInstance.validators.call(inputValidatorInfo.validator);
    assert.strictEqual(
      ValidatorStatus.Staked.toString(),
      insertedValidator.status.toString(10),
      `Expected validator status is ${ValidatorStatus.Staked} but found ${insertedValidator.status} `,
    );
    assert.strictEqual(
      inputValidatorInfo.reputation.toString(10),
      insertedValidator.reputation.toString(10),
      `Expected validator reputation is ${inputValidatorInfo.reputation} but found ${insertedValidator.reputation} `,
    );
  });

  it('should add validator in Deregistered state when his reputation is zero', async () => {
    await coreputationInstance.upsertValidator(
      inputValidatorInfo.validator,
      new BN(0),
      { from: coconsensus },
    );
    const insertedValidator = await coreputationInstance.validators.call(inputValidatorInfo.validator);

    assert.strictEqual(
      ValidatorStatus.Deregistered.toString(),
      insertedValidator.status.toString(10),
      `Expected validator status is ${ValidatorStatus.Deregistered} but found ${insertedValidator.status} `,
    );
    assert.strictEqual(
      (new BN(0)).toString(10),
      insertedValidator.reputation.toString(10),
      `Expected validator reputation is ${(new BN(0)).toString(10)} but found ${insertedValidator.reputation} `,
    );
  });

  it('should update validator status to Deregistered when reputation is zero', async () => {
    await coreputationInstance.upsertValidator(
      inputValidatorInfo.validator,
      inputValidatorInfo.reputation,
    );
    await coreputationInstance.upsertValidator(
      inputValidatorInfo.validator,
      new BN(0),
    );
    const updatedValidator = await coreputationInstance.validators.call(inputValidatorInfo.validator);
    assert.strictEqual(
      ValidatorStatus.Deregistered.toString(),
      updatedValidator.status.toString(10),
      `Expected validator status is ${ValidatorStatus.Deregistered} but found ${updatedValidator.status} `,
    );

    assert.strictEqual(
      '0',
      updatedValidator.reputation.toString(10),
      `Expected validator reputation is 0 but found ${updatedValidator.reputation} `,
    );
  });

  it('should not update validator information in slashed state', async () => {
    await coreputationInstance.upsertValidator(
      inputValidatorInfo.validator,
      inputValidatorInfo.reputation,
    );
    await coreputationInstance.setValidatorSlashed(
      inputValidatorInfo.validator,
    );
    await coreputationInstance.upsertValidator(
      inputValidatorInfo.validator,
      new BN(20),
    );

    const updatedValidator = await coreputationInstance.validators.call(inputValidatorInfo.validator);
    assert.strictEqual(
      ValidatorStatus.Slashed.toString(),
      updatedValidator.status.toString(10),
      `Expected validator status is ${ValidatorStatus.Slashed} but found ${updatedValidator.status} `,
    );

    assert.strictEqual(
      (new BN(0)).toString(10),
      updatedValidator.reputation.toString(10),
      `Expected validator reputation is 0 but found ${updatedValidator.reputation.toString(10)} `,
    );
  });
});