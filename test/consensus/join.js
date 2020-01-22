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

const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');

const Consensus = artifacts.require('ConsensusTest');
const SpyReputation = artifacts.require('SpyReputation');
const SpyCore = artifacts.require('SpyCore');

contract('Consensus::join', (accounts) => {
  const accountProvider = new Utils.AccountProvider(accounts);

  let consensus;
  let reputation;
  let core;

  let joinParams = {};

  beforeEach(async () => {
    consensus = await Consensus.new();
    reputation = await SpyReputation.new();
    core = await SpyCore.new();

    await consensus.setReputation(reputation.address);
    await consensus.setCoreLifetime(
      core.address,
      consensusUtil.CoreLifetime.active,
    );

    joinParams = {
      metachainId: '0x0000000000000000000000000000000000000222',
      withdrawalAddress: accountProvider.get(),
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(joinParams);

    await consensus.setAssignment(joinParams.metachainId, core.address);
  });

  contract('Negative Tests', async () => {
    it('should fail when metachainId is invalid', async () => {
      const invalidJoinParams = Object.assign(
        {},
        joinParams,
        { metachainId: Utils.NULL_ADDRESS },
      );
      await Utils.expectRevert(
        consensusUtil.join(consensus, invalidJoinParams),
        'Core does not exist for given metachain.',
      );
    });

    it('should fail when core status is undefined', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.undefined,
      );
      await Utils.expectRevert(
        consensusUtil.join(consensus, joinParams),
        'Core lifetime status must be genesis or active.',
      );
    });

    it('should fail when core status is halted', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.halted,
      );
      await Utils.expectRevert(
        consensusUtil.join(consensus, joinParams),
        'Core lifetime status must be genesis or active.',
      );
    });

    it('should fail when core status is corrupted', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.corrupted,
      );
      await Utils.expectRevert(
        consensusUtil.join(consensus, joinParams),
        'Core lifetime status must be genesis or active.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should pass when core status is genesis', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.genesis,
      );
      await consensusUtil.join(consensus, joinParams);
    });

    it('should pass when core status is activated', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.active,
      );
      await consensusUtil.join(consensus, joinParams);
    });

    it('should call join function of reputation contract with correct params', async () => {
      await consensusUtil.join(consensus, joinParams);

      const validator = await reputation.validator.call();
      assert.strictEqual(
        validator,
        joinParams.txOptions.from,
        'Validator address not set in spy reputation contract',
      );

      const spyWithdrawalAddress = await reputation.spyWithdrawalAddress.call();
      assert.strictEqual(
        spyWithdrawalAddress,
        joinParams.withdrawalAddress,
        'Withdrawal address not set in spy reputation contract',
      );
    });

    it('should call join function of core contract with correct params', async () => {
      await consensusUtil.join(consensus, joinParams);

      const spyValidator = await core.spyValidator.call();
      assert.strictEqual(
        spyValidator,
        joinParams.txOptions.from,
        'Validator address not set in spy core contract',
      );
    });
  });
});
