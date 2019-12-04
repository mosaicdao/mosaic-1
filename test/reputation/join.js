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

const BN = require('bn.js');

const { AccountProvider, NULL_ADDRESS } = require('../test_lib/utils.js');
const { ValidatorStatus } = require('./utils.js');
const Utils = require('../test_lib/utils.js');

const Reputation = artifacts.require('Reputation');
const MockToken = artifacts.require('MockToken');

contract('Reputation::join', (accounts) => {
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
      initialReputation: 10,
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
  });

  it('should be able to join validator pool', async () => {
    const response = await reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    );

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );
  });

  it('should create storage for validator', async () => {
    const response = await reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    );

    assert.isOk(
      response.receipt.status,
      'Receipt status must be true',
    );

    const validatorObject = await reputation.validators.call(validator.address);

    assert.isOk(
      validatorObject.status.eqn(ValidatorStatus.Staked),
      'Validator status must be staked',
    );

    assert.isOk(
      validatorObject.reputation.eqn(constructorArgs.initialReputation),
      `Initial reputation should be ${constructorArgs.initialReputation.toString(10)}`
        + ` but found ${validatorObject.reputation.toString(10)}`,
    );

    assert.strictEqual(
      validatorObject.withdrawalAddress,
      validator.withdrawalAddress,
      'Withdrawal address must match',
    );

    assert.isOk(
      validatorObject.withdrawalBlockHeight.eq(new BN('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', 16)),
      'Withdrawal block height must be max value uint256',
    );

    assert.isOk(
      validatorObject.lockedEarnings.eqn(0),
      true,
      `Locked earnings must be zero but found ${validatorObject.lockedEarnings.toString(10)}`,
    );

    assert.isOk(
      validatorObject.cashableEarnings.eqn(0),
      true,
      `Cashable earnings must be zero but found ${validatorObject.cashableEarnings.toString(10)}`,
    );
  });

  it('should increase reputation contract balance', async () => {
    await reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    );

    const reputationMOSTBalance = await mOST.balanceOf.call(reputation.address);
    const reputationWETHBalance = await wETH.balanceOf.call(reputation.address);

    assert.isOk(
      reputationMOSTBalance.eqn(constructorArgs.stakeMOSTAmount),
      `Expected mOST balance is ${constructorArgs.stakeMOSTAmount} but found ${reputationMOSTBalance.toString(10)}`,
    );

    assert.isOk(
      reputationWETHBalance.eqn(constructorArgs.stakeWETHAmount),
      `Expected wETH balance is ${constructorArgs.stakeWETHAmount} but found ${reputationWETHBalance.toString(10)}`,
    );
  });

  it('should fail in non consensus address tries to join a validator', async () => {
    const nonConsensusAddress = accountProvider.get();

    await Utils.expectRevert(reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: nonConsensusAddress },
    ),
    'Only the consensus contract can call this function.');
  });
  it('should fail to join validator pool if mOST token is not approved', async () => {
    await mOST.approve(
      reputation.address,
      '0',
      { from: validator.address },
    );

    // Can't assert message, because transferFrom will revert/throw as per the specification.
    // https://eips.ethereum.org/EIPS/eip-20
    await Utils.expectRevert(reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    ));
  });

  it('should fail to join validator pool if wETH token is not approved', async () => {
    await wETH.approve(
      reputation.address,
      '0',
      { from: validator.address },
    );

    // Can't assert message, because transferFrom will revert/throw as per the specification.
    // https://eips.ethereum.org/EIPS/eip-20
    await Utils.expectRevert(reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    ));
  });

  it('should fail for zero validator address', async () => {
    await Utils.expectRevert(reputation.join(
      NULL_ADDRESS,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    ),
    'Validator address is 0.');
  });

  it('should fail for zero withdrawal address', async () => {
    await Utils.expectRevert(reputation.join(
      validator.address,
      NULL_ADDRESS,
      { from: constructorArgs.consensus },
    ),
    'Validator\'s withdrawal address is 0.');
  });

  it('should fail if validator address is same as withdrawal address', async () => {
    await Utils.expectRevert(reputation.join(
      validator.address,
      validator.address,
      { from: constructorArgs.consensus },
    ),
    'Validator\'s address is the same as its withdrawal address.');
  });

  it('should fail if validator has already joined', async () => {
    await reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    );

    await Utils.expectRevert(reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    ),
    'No validator can rejoin.');
  });

  it('should fail if withdrawal address has already joined as validator', async () => {
    await mOST.transfer(
      validator.withdrawalAddress,
      constructorArgs.stakeMOSTAmount,
      { from: validator.address },
    );
    await wETH.transfer(
      validator.withdrawalAddress,
      constructorArgs.stakeWETHAmount,
      { from: validator.address },
    );

    await mOST.approve(
      reputation.address,
      constructorArgs.stakeMOSTAmount,
      { from: validator.withdrawalAddress },
    );

    await wETH.approve(
      reputation.address,
      constructorArgs.stakeWETHAmount,
      { from: validator.withdrawalAddress },
    );
    await reputation.join(
      validator.withdrawalAddress,
      validator.address,
      { from: constructorArgs.consensus },
    );
    await Utils.expectRevert(reputation.join(
      validator.address,
      validator.withdrawalAddress,
      { from: constructorArgs.consensus },
    ),
    'The specified withdrawal address was registered as validator.');
  });
});
