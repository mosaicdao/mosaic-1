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
const Utils = require('../test_lib/utils.js');

const Reputation = artifacts.require('Reputation');
const MockToken = artifacts.require('MockToken');

contract('Reputation::depositEarnings', (accounts) => {
  let constructorArgs;
  let validator;
  let accountProvider;
  let reputation;
  let most;
  let wETH;
  let depositor;

  beforeEach(async () => {
    accountProvider = new AccountProvider(accounts);
    validator = {
      address: accountProvider.get(),
      withdrawalAddress: accountProvider.get(),
    };
    most = await MockToken.new(18, { from: validator.address });
    wETH = await MockToken.new(18, { from: validator.address });

    depositor = accountProvider.get();

    const funds = '1000000000000000000000';
    await most.transfer(depositor, funds, { from: validator.address });

    constructorArgs = {
      consensus: accountProvider.get(),
      most: most.address,
      stakeMOSTAmount: 200,
      wETH: wETH.address,
      stakeWETHAmount: 100,
      cashableEarningsPerMille: 499,
      initialReputation: 10,
      withdrawalCooldownPeriodInBlocks: 10,
    };

    reputation = await Reputation.new();
    await reputation.setup(
      constructorArgs.consensus,
      constructorArgs.most,
      constructorArgs.stakeMOSTAmount,
      constructorArgs.wETH,
      constructorArgs.stakeWETHAmount,
      constructorArgs.cashableEarningsPerMille,
      constructorArgs.initialReputation,
      constructorArgs.withdrawalCooldownPeriodInBlocks,
    );

    await most.approve(reputation.address, funds, { from: depositor });

    await most.approve(
      reputation.address,
      constructorArgs.stakeMOSTAmount,
      { from: validator.address },
    );

    await wETH.approve(
      reputation.address,
      constructorArgs.stakeWETHAmount,
      { from: validator.address },
    );

    await reputation.stake(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    );
  });

  it('should deposit earning for a validator', async () => {
    const amount = 111;
    const response = await reputation.depositEarnings(
      validator.address,
      amount,
      { from: depositor },
    );

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );
  });

  it('should transfer funds to reputation contract', async () => {
    const amount = 111;

    const initialBalance = await most.balanceOf(reputation.address);
    await reputation.depositEarnings(
      validator.address,
      amount,
      { from: depositor },
    );

    const finalBalance = await most.balanceOf(reputation.address);

    assert.isOk(
      finalBalance.sub(initialBalance).eqn(amount),
      `Expected increase in balance is ${amount} but found ${finalBalance.sub(initialBalance)}`,
    );
  });

  it('should maintain cash-able and locked earning based on cashableEarningsPerMille ', async () => {
    const amount = 1000;
    const cashableEarnings = 499;
    const lockedEarnings = 501;

    await reputation.depositEarnings(
      validator.address,
      amount,
      { from: depositor },
    );

    const validatorObject = await reputation.validators.call(validator.address);

    assert.isOk(
      validatorObject.cashableEarnings.eqn(cashableEarnings),
      `Validator cashable earnings must be ${cashableEarnings} but found ${validatorObject.cashableEarnings.toString(0)}`,
    );

    assert.isOk(
      validatorObject.lockedEarnings.eqn(lockedEarnings),
      `Validator locked earnings must be ${lockedEarnings} but found ${validatorObject.lockedEarnings.toString(0)}`,
    );
  });

  it('should fail for an unknown validator', async () => {
    const amount = 1000;
    const unknownValidator = accountProvider.get();

    await Utils.expectRevert(reputation.depositEarnings(
      unknownValidator,
      amount,
      { from: depositor },
    ),
      'Validator is not active.');
  });

  it('should fail for logged out validator', async () => {
    const amount = 1000;

    await reputation.deregister(validator.address, { from: constructorArgs.consensus });

    await Utils.expectRevert(reputation.depositEarnings(
      validator.address,
      amount,
      { from: depositor },
    ),
      'Validator is not active.');
  });

  it('should fail for withdrawn validator', async () => {
    const amount = 1000;

    await reputation.deregister(validator.address, { from: constructorArgs.consensus });

    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);

    await reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.depositEarnings(
      validator.address,
      amount,
      { from: depositor },
    ),
      'Validator is not active.');
  });
});
