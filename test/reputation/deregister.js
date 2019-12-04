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

const { AccountProvider } = require('../test_lib/utils.js');
const { ValidatorStatus } = require('./utils.js');
const Utils = require('../test_lib/utils.js');

const Reputation = artifacts.require('Reputation');
const MockToken = artifacts.require('MockToken');

contract('Reputation::deregister', (accounts) => {
  let constructorArgs;
  let validator;
  let accountProvider;
  let reputation;
  let mOST;
  let wETH;

  beforeEach(async () => {
    accountProvider = new AccountProvider(accounts);
    validator = {
      address: accountProvider.get(),
      withdrawalAddress: accountProvider.get(),
    };
    mOST = await MockToken.new(18, { from: validator.address });
    wETH = await MockToken.new(18, { from: validator.address });

    constructorArgs = {
      consensus: accountProvider.get(),
      mOST: mOST.address,
      stakeMOSTAmount: 200,
      wETH: wETH.address,
      stakeWETHAmount: 100,
      cashableEarningsPerMille: 100,
      initialReputation: 100,
      withdrawalCooldownPeriodInBlocks: 10,
    };

    reputation = await Reputation.new();
    await reputation.setup(
      constructorArgs.consensus,
      constructorArgs.mOST,
      constructorArgs.stakeMOSTAmount,
      constructorArgs.wETH,
      constructorArgs.stakeWETHAmount,
      constructorArgs.cashableEarningsPerMille,
      constructorArgs.initialReputation,
      constructorArgs.withdrawalCooldownPeriodInBlocks,
    );

    await mOST.approve(
      reputation.address,
      constructorArgs.stakeMOSTAmount,
      { from: validator.address },
    );

    await wETH.approve(
      reputation.address,
      constructorArgs.stakeWETHAmount,
      { from: validator.address },
    );

    await reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    );
  });

  it('should be able to deregister', async () => {
    const response = await reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    );

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );

    const validatorObject = await reputation.validators.call(validator.address);

    assert.isOk(
      validatorObject.status.eqn(ValidatorStatus.DeRegistered),
      `Expected status is ${ValidatorStatus.DeRegistered} but found ${validatorObject.status}`,
    );
    const expectedWithdrawalBlockHeight = response.receipt.blockNumber
      + constructorArgs.withdrawalCooldownPeriodInBlocks;

    assert.isOk(
      validatorObject.withdrawalBlockHeight.eqn(expectedWithdrawalBlockHeight),
      `Expected withdrawal block height is ${expectedWithdrawalBlockHeight} but found  ${validatorObject.withdrawalBlockHeight.toString(10)}`,
    );
  });

  it('should fail for unknown validator', async () => {
    const unknownValidator = accountProvider.get();

    await Utils.expectRevert(reputation.deregister(
      unknownValidator,
      { from: constructorArgs.consensus },
    ),
    'Validator is not active.');
  });

  it('should fail if transaction is done by account other than consensus', async () => {
    const otherAccount = accountProvider.get();

    await Utils.expectRevert(reputation.deregister(
      validator.address,
      { from: otherAccount },
    ),
    'Only the consensus contract can call this function.');
  });

  it('should fail for deregistered validator', async () => {
    await reputation.deregister(validator.address, { from: constructorArgs.consensus });

    await Utils.expectRevert(reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator is not active.');
  });

  it('should fail for withdraw-ed validator', async () => {
    await reputation.deregister(validator.address, { from: constructorArgs.consensus });
    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);
    await reputation.withdraw(validator.address, { from: constructorArgs.consensus });

    await Utils.expectRevert(reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator is not active.');
  });

  it('should fail for slashed validator', async () => {
    await reputation.slash(validator.address, { from: constructorArgs.consensus });

    await Utils.expectRevert(reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator is not active.');
  });
});
