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

const { AccountProvider, NULL_ADDRESS } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const Reputation = artifacts.require('Reputation');

contract('Reputation::constructor', (accounts) => {
  let constructorArgs;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    constructorArgs = {
      consensus: accountProvider.get(),
      mOST: accountProvider.get(),
      stakeMOSTAmount: 200,
      wETH: accountProvider.get(),
      stakeWETHAmount: 100,
      cashableEarningsPerMille: 100,
      initialReputation: 10,
      withdrawalCooldownPeriodInBlocks: 10,
    };
  });

  it('should successfully construct reputation contract', async () => {
    const reputation = await Reputation.new(
      constructorArgs.consensus,
      constructorArgs.mOST,
      constructorArgs.stakeMOSTAmount,
      constructorArgs.wETH,
      constructorArgs.stakeWETHAmount,
      constructorArgs.cashableEarningsPerMille,
      constructorArgs.initialReputation,
      constructorArgs.withdrawalCooldownPeriodInBlocks,
    );

    const consensus = await reputation.consensus.call();
    const mOST = await reputation.mOST.call();
    const wETH = await reputation.wETH.call();
    const stakeMOSTAmount = await reputation.stakeMOSTAmount.call();
    const stakeWETHAmount = await reputation.stakeWETHAmount.call();
    const initialReputation = await reputation.initialReputation.call();
    const cashableEarningsPerMille = await reputation.cashableEarningsPerMille.call();
    const withdrawalCooldownPeriodInBlocks = await reputation
      .withdrawalCooldownPeriodInBlocks.call();


    assert.strictEqual(
      consensus === constructorArgs.consensus,
      true,
      `consensus address is set to ${consensus} and is not ${constructorArgs.consensus}.`,
    );

    assert.strictEqual(
      mOST === constructorArgs.mOST,
      true,
      `mOST address is set to ${mOST} and is not ${constructorArgs.mOST}.`,
    );

    assert.strictEqual(
      wETH === constructorArgs.wETH,
      true,
      `wETH address is set to ${wETH} and is not ${constructorArgs.wETH}.`,
    );

    assert.isOk(
      stakeMOSTAmount.eqn(constructorArgs.stakeMOSTAmount),
      true,
      `stake MOST amount set to ${stakeMOSTAmount.toString(10)} but expected ${constructorArgs.stakeMOSTAmount.toString(10)}`,
    );

    assert.isOk(
      stakeWETHAmount.eqn(constructorArgs.stakeWETHAmount),
      true,
      `stake WETH amount set to ${stakeWETHAmount.toString(10)} but expected ${constructorArgs.stakeWETHAmount.toString(10)}`,
    );

    assert.isOk(
      initialReputation.eqn(constructorArgs.initialReputation),
      true,
      `initialReputation set to ${initialReputation.toString(10)} but expected ${constructorArgs.initialReputation.toString(10)}`,
    );

    assert.isOk(
      cashableEarningsPerMille.eqn(constructorArgs.cashableEarningsPerMille),
      true,
      `cashableEarningsPerMille set to ${cashableEarningsPerMille.toString(10)} but expected ${constructorArgs.cashableEarningsPerMille.toString(10)}`,
    );

    assert.isOk(
      withdrawalCooldownPeriodInBlocks.eqn(constructorArgs.withdrawalCooldownPeriodInBlocks),
      true,
      `withdrawalCooldownPeriodInBlocks set to ${withdrawalCooldownPeriodInBlocks.toString(10)} but expected ${constructorArgs.withdrawalCooldownPeriodInBlocks.toString(10)}`,
    );
  });

  it('should fail to construct with zero consensus address', async () => {
    constructorArgs.consensus = NULL_ADDRESS;

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'consensus token address is 0.',
    );
  });

  it('should fail to construct with zero mOST address', async () => {
    constructorArgs.mOST = NULL_ADDRESS;

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'mOST token address is 0.',
    );
  });

  it('should fail to construct with zero stake MOST Amount', async () => {
    constructorArgs.stakeMOSTAmount = '0';

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'Stake amount to join in mOST is not positive.',
    );
  });

  it('should fail to construct with zero wETH address', async () => {
    constructorArgs.wETH = NULL_ADDRESS;

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'wETH token address is 0.',
    );
  });

  it('should fail to construct with zero stake WETH Amount', async () => {
    constructorArgs.stakeWETHAmount = '0';

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'Stake amount to join in wETH is not positive.',
    );
  });

  it('should fail to construct with cashable earning per mille is more than 1000', async () => {
    constructorArgs.cashableEarningsPerMille = '1001';

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'Cashable earnings is not in valid range:',
    );
  });

  it('should fail to construct with withdrawal cooldown period in blocks is zero', async () => {
    constructorArgs.withdrawalCooldownPeriodInBlocks = 0;

    await Utils.expectRevert(
      Reputation.new(
        constructorArgs.consensus,
        constructorArgs.mOST,
        constructorArgs.stakeMOSTAmount,
        constructorArgs.wETH,
        constructorArgs.stakeWETHAmount,
        constructorArgs.cashableEarningsPerMille,
        constructorArgs.initialReputation,
        constructorArgs.withdrawalCooldownPeriodInBlocks,
      ),
      'Withdrawal cooldown period in blocks must be greater than zero.',
    );
  });
});
