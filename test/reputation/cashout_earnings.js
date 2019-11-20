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

contract('Reputation::cashoutEarnings', (accounts) => {
  let constructorArgs;
  let validator;
  let accountProvider;
  let reputation;
  let mOST;
  let wETH;
  let depositor;

  beforeEach(async () => {
    accountProvider = new AccountProvider(accounts);
    validator = {
      address: accountProvider.get(),
      withdrawalAddress: accountProvider.get(),
    };
    mOST = await MockToken.new(18, { from: validator.address });
    wETH = await MockToken.new(18, { from: validator.address });

    depositor = accountProvider.get();

    const funds = '1000000000000000000000';
    await mOST.transfer(depositor, funds, { from: validator.address });

    constructorArgs = {
      consensus: accountProvider.get(),
      mOST: mOST.address,
      stakeMOSTAmount: 200,
      wETH: wETH.address,
      stakeWETHAmount: 100,
      cashableEarningsPerMille: 499,
      initialReputation: 10,
      withdrawalCooldownPeriodInBlocks: 10,
    };

    reputation = await Reputation.new(
      constructorArgs.consensus,
      constructorArgs.mOST,
      constructorArgs.stakeMOSTAmount,
      constructorArgs.wETH,
      constructorArgs.stakeWETHAmount,
      constructorArgs.cashableEarningsPerMille,
      constructorArgs.initialReputation,
      constructorArgs.withdrawalCooldownPeriodInBlocks,
    );

    await mOST.approve(reputation.address, funds, { from: depositor });

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

    const depositAmount = 1000;
    await reputation.depositEarnings(
      validator.address,
      depositAmount,
      { from: depositor },
    );
  });

  it('should cash-out earning for a validator', async () => {
    const cashOutAmount = 499;
    const initialBalance = await mOST.balanceOf(validator.withdrawalAddress);

    await reputation.cashOutEarnings(
      cashOutAmount,
      { from: validator.address },
    );

    const finalBalance = await mOST.balanceOf(validator.withdrawalAddress);

    assert.isOk(
      finalBalance.sub(initialBalance).eqn(cashOutAmount),
      `It must increase withdrawal address balance by ${cashOutAmount} but increased by ${finalBalance.sub(initialBalance)}`,
    );
  });

  it('should allow cashout of earnings for logged out validator', async () => {
    const amount = 499;

    await reputation.logout(validator.address, { from: constructorArgs.consensus });

    const response = await reputation.cashOutEarnings(
      amount,
      { from: validator.address },
    );

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );
  });

  it('should fail if it tries to withdraw more than cashable amount', async () => {
    const cashOutAmount = 500;

    await Utils.expectRevert(
      reputation.cashOutEarnings(
        cashOutAmount,
        { from: validator.address },
      ),
      'The specified amount is bigger than available cashable amount.',
    );
  });

  it('should fail for an unknown validator', async () => {
    const amount = 499;
    const unknownValidator = accountProvider.get();

    await Utils.expectRevert(reputation.cashOutEarnings(
      amount,
      { from: unknownValidator },
    ),
    'Validator has not joined.');
  });

  it('should fail for slashed validator', async () => {
    const amount = 499;

    await reputation.slash(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.cashOutEarnings(
      amount,
      { from: validator.address },
    ),
    'Validator is not honest.');
  });

  it('should fail for withdrawn validator', async () => {
    const amount = 499;

    await reputation.logout(validator.address, { from: constructorArgs.consensus });
    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);
    await reputation.withdraw(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.cashOutEarnings(
      amount,
      { from: validator.address },
    ),
    'Validator has withdrawn.');
  });
});
