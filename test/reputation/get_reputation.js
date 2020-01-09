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

contract('Reputation::getReputation', (accounts) => {
  let constructorArgs;
  let validator;
  let accountProvider;
  let reputation;
  let most;
  let wETH;
  const increasedReputation = 100;

  beforeEach(async () => {
    accountProvider = new AccountProvider(accounts);
    validator = {
      address: accountProvider.get(),
      withdrawalAddress: accountProvider.get(),
    };
    most = await Utils.deployMockToken(validator.address);
    wETH = await Utils.deployMockToken(validator.address);

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
    await reputation.increaseReputation(
      validator.address,
      increasedReputation,
      { from: constructorArgs.consensus },
    );
  });

  it('should return correct reputation for a known validator', async () => {
    const reputationValue = await reputation.getReputation.call(validator.address);

    assert.isOk(
      reputationValue.eqn(increasedReputation + constructorArgs.initialReputation),
      `Expected reputation is ${increasedReputation + constructorArgs.initialReputation} but found ${reputationValue.toString(10)}`,
    );
  });

  it('should return zero reputation for a unknown validator', async () => {
    const unknownValidator = accountProvider.get();
    const reputationValue = await reputation.getReputation.call(unknownValidator);

    assert.isOk(
      reputationValue.eqn(0),
      `Expected reputation is ${0} but found ${reputationValue.toString(10)}`,
    );
  });
});
