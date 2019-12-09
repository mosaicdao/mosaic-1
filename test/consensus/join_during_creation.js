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
const CoreStatusUtils = require('../test_lib/core_status_utils');

const Consensus = artifacts.require('ConsensusTest');
const SpyReputation = artifacts.require('SpyReputation');
const SpyCore = artifacts.require('SpyCore');

contract('Consensus::joinDuringCreation', (accounts) => {
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
    await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.creation);

    joinParams = {
      metachainId: Utils.getRandomHash(),
      core: core.address,
      withdrawalAddress: accountProvider.get(),
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(joinParams);

    await consensus.setAssignment(joinParams.metachainId, core.address);
  });

  contract('Negative Tests', async () => {
    it('should fail when metachain id is 0', async () => {
      const params = Object.assign(
        {},
        joinParams,
        { metachainId: Utils.NULL_ADDRESS },
      );
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, params),
        'Metachain id is 0.',
      );
    });

    it('should fail when core address is 0', async () => {
      const params = Object.assign(
        {},
        joinParams,
        { core: Utils.NULL_ADDRESS },
      );

      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, params),
        'Core address is 0.',
      );
    });

    it('should fail when core is not assigned for specified metachain id', async () => {
      const params = Object.assign(
        {},
        joinParams,
        { core: accountProvider.get() },
      );

      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, params),
        'Core is not assigned for the specified metachain id.',
      );
    });

    it('should fail when withdrawal address is 0', async () => {
      const params = Object.assign(
        {},
        joinParams,
        { withdrawalAddress: Utils.NULL_ADDRESS },
      );

      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, params),
        'Withdrawal address is 0.',
      );
    });

    it('should fail when core status is undefined', async () => {
      await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.undefined);
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, joinParams),
        'Core must be in an active state.',
      );
    });

    it('should fail when core status is halted', async () => {
      await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.halted);
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, joinParams),
        'Core must be in an active state.',
      );
    });

    it('should fail when core status is corrupted', async () => {
      await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.corrupted);
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, joinParams),
        'Core must be in an active state.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should pass when core status is creation', async () => {
      await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.creation);
      await consensusUtil.joinDuringCreation(consensus, joinParams);
    });

    it('should pass when core status is opened', async () => {
      await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.opened);
      await consensusUtil.joinDuringCreation(consensus, joinParams);
    });

    it('should pass when core status is precommited', async () => {
      await consensus.setCoreStatus(core.address, CoreStatusUtils.CoreStatus.precommitted);
      await consensusUtil.joinDuringCreation(consensus, joinParams);
    });

    it('should call join function of reputation contract with correct params', async () => {
      await consensusUtil.joinDuringCreation(consensus, joinParams);

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
      await consensusUtil.joinDuringCreation(consensus, joinParams);

      const spyValidator = await core.spyValidator.call();
      assert.strictEqual(
        spyValidator,
        joinParams.txOptions.from,
        'Validator address not set in spy core contract',
      );
    });
  });
});
