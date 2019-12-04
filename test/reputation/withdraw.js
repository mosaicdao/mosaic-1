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

contract('Reputation::withdraw', (accounts) => {
  let constructorArgs;
  let validator;
  let accountProvider;
  let reputation;
  let mOST;
  let wETH;
  const validatorEarnings = 101;

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

  it('should be able to withdraw after cool down period', async () => {
    await reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    );
    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);

    const response = await reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    );

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );

    const validatorObject = await reputation.validators.call(validator.address);

    assert.isOk(
      validatorObject.status.eqn(ValidatorStatus.Withdrawn),
      `Expected status is ${ValidatorStatus.LoggedOut} but found ${validatorObject.status}`,
    );
  });

  it('should receive funds after withdrawal', async () => {
    const beforeWETHBalance = await wETH.balanceOf(validator.withdrawalAddress);
    const beforeMOSTBalance = await mOST.balanceOf(validator.withdrawalAddress);

    await mOST.approve(reputation.address, validatorEarnings, { from: validator.address });
    await reputation.depositEarnings(validator.address, validatorEarnings);

    await reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);

    await reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    );

    const afterWETHBalance = await wETH.balanceOf(validator.withdrawalAddress);
    const afterMOSTBalance = await mOST.balanceOf(validator.withdrawalAddress);

    const diffInWETHBalance = afterWETHBalance.sub(beforeWETHBalance);
    const diffInMOSTBalance = afterMOSTBalance.sub(beforeMOSTBalance);

    assert.isOk(
      diffInWETHBalance.eqn(constructorArgs.stakeWETHAmount),
      'WETH staked amount should be returned to validator. Expected balance'
      + ` is ${beforeWETHBalance.addn(constructorArgs.stakeWETHAmount).toString(10)} but found ${afterWETHBalance.toString(10)}`,
    );

    assert.isOk(
      diffInMOSTBalance.eqn(constructorArgs.stakeMOSTAmount + validatorEarnings),
      'MOST staked amount should be returned to validator. Expected balance'
      + `is ${beforeMOSTBalance.addn(constructorArgs.stakeMOSTAmount + validatorEarnings).toString(10)}`
      + ` but found ${afterMOSTBalance.toString(10)}`,
    );
  });

  it('should fail to withdraw if validator is not logged out', async () => {
    await Utils.expectRevert(reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator has not deregistered.');
  });

  it('should fail to withdraw if validator is not logged out', async () => {
    await Utils.expectRevert(reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator has not deregistered.');
  });

  it('should fail to withdraw if validator is slashed', async () => {
    await reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await reputation.slash(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator has not deregistered.');
  });

  it('should fail to withdraw if cool down period has not elapsed', async () => {
    await reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Withdrawal cooldown period has not elapsed.');
  });

  it('should fail if validator is already withdrawn', async () => {
    await reputation.deregister(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);

    await reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator has withdrawn.');
  });
});
