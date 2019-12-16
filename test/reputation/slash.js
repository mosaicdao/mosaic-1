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

contract('Reputation::slash', (accounts) => {
  let constructorArgs;
  let validator;
  let accountProvider;
  let reputation;
  let most;
  let wETH;
  const validatorEarnings = 101;

  beforeEach(async () => {
    accountProvider = new AccountProvider(accounts);
    validator = {
      address: accountProvider.get(),
      withdrawalAddress: accountProvider.get(),
    };
    most = await MockToken.new(18, { from: validator.address });
    wETH = await MockToken.new(18, { from: validator.address });

    constructorArgs = {
      consensus: accountProvider.get(),
      most: most.address,
      stakeMOSTAmount: 200,
      wETH: wETH.address,
      stakeWETHAmount: 100,
      cashableEarningsPerMille: 100,
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

    await most.approve(reputation.address, validatorEarnings, { from: validator.address });
    await reputation.depositEarnings(validator.address, validatorEarnings);
  });

  it('should be able to slash a validator', async () => {
    const beforeWETHBalance = await wETH.balanceOf(reputation.address);
    const beforeMOSTBalance = await most.balanceOf(reputation.address);

    const response = await reputation.slash(
      validator.address,
      { from: constructorArgs.consensus },
    );

    const afterWETHBalance = await wETH.balanceOf(reputation.address);
    const afterMOSTBalance = await most.balanceOf(reputation.address);

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );

    assert.isOk(
      beforeWETHBalance.sub(afterWETHBalance).eqn(constructorArgs.stakeWETHAmount),
      `WETH staked amount must be burned expected change is balance is ${constructorArgs.stakeWETHAmount} but `
      + `found ${beforeMOSTBalance.sub(afterWETHBalance)} `,
    );

    assert.isOk(
      beforeMOSTBalance.sub(afterMOSTBalance)
        .eqn(constructorArgs.stakeMOSTAmount + validatorEarnings),
      `MOST staked amount and earning must be burned expected change is balance is ${constructorArgs.stakeMOSTAmount + validatorEarnings} but `
      + `found ${beforeMOSTBalance.sub(afterWETHBalance)} `,
    );
  });

  it('should fail if transaction is done by account other than consensus', async () => {
    const otherAccount = accountProvider.get();

    await Utils.expectRevert(reputation.slash(
      validator.address,
      { from: otherAccount },
    ),
    'Only the consensus contract can call this function.');
  });

  it.skip('should fail if validator has not joined', async () => {
    const otherAccount = accountProvider.get();

    await Utils.expectRevert(reputation.slash(
      otherAccount,
      { from: constructorArgs.consensus },
    ),
    'Validator has not staked.');
  });


  it('should fail if validator has already withdrawn', async () => {
    await reputation.deregister(validator.address, { from: constructorArgs.consensus });
    await Utils.advanceBlocks(constructorArgs.withdrawalCooldownPeriodInBlocks + 1);
    await reputation.withdraw(validator.address, { from: constructorArgs.consensus });

    await Utils.expectRevert(reputation.slash(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator has withdrawn.');
  });

  it('should fail to slash already slashed validator', async () => {
    await reputation.slash(
      validator.address,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.slash(
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator has slashed.');
  });
});
