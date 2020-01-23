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

const CoReputation = artifacts.require('CoreputationTest');

contract('Coreputation::getReputation', (accounts) => {
  let accountProvider;
  let coReputation;
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
    coReputation = await CoReputation.new();
    coconsensus = accountProvider.get();
    inputValidatorInfo = {
      validator: accountProvider.get(),
      reputation: new BN('10'),
    };
    await coReputation.setup(coconsensus);
  });

  it('should add validator in Staked state', async () => {
    await coReputation.upsertValidator(
      inputValidatorInfo.validator,
      inputValidatorInfo.reputation,
      { from: coconsensus },
    );
    const insertedValidator = await coReputation.validators.call(inputValidatorInfo.validator);
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

  it('should update validator status to Deregistered when reputation is zero', async () => {
    await coReputation.upsertValidator(
      inputValidatorInfo.validator,
      inputValidatorInfo.reputation,
    );
    await coReputation.upsertValidator(
      inputValidatorInfo.validator,
      new BN(0),
    );
    const updatedValidator = await coReputation.validators.call(inputValidatorInfo.validator);
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
});
