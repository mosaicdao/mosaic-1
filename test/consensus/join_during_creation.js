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
const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');

const Consensus = artifacts.require('ConsensusTest');
const SpyReputation = artifacts.require('SpyReputation');
const SpyCore = artifacts.require('SpyCore');
const SpyConsensusGateway = artifacts.require('SpyConsensusGateway');

contract('Consensus::joinDuringCreation', (accounts) => {
  const accountProvider = new Utils.AccountProvider(accounts);

  let consensus;
  let reputation;
  let core;
  let consensusGateway;

  let joinParams = {};

  beforeEach(async () => {
    consensus = await Consensus.new();
    reputation = await SpyReputation.new();
    core = await SpyCore.new();
    consensusGateway = await SpyConsensusGateway.new();

    await consensus.setReputation(reputation.address);
    await consensus.setCoreLifetime(
      core.address,
      consensusUtil.CoreLifetime.creation,
    );

    joinParams = {
      metachainId: Utils.getRandomHash(),
      withdrawalAddress: accountProvider.get(),
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(joinParams);

    await consensus.setAssignment(joinParams.metachainId, core.address);
    await consensus.setConsensusGateway(joinParams.metachainId, consensusGateway.address);
  });

  contract('Negative Tests', async () => {
    it('should fail when metachainId is invalid', async () => {
      const invalidJoinParams = Object.assign(
        {},
        joinParams,
        { metachainId: Utils.NULL_ADDRESS },
      );
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, invalidJoinParams),
        'Core does not exist for given metachain.',
      );
    });

    it('should fail when core status is undefined', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.undefined,
      );
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, joinParams),
        'Core lifetime status must be creation.',
      );
    });

    it('should fail when core status is halted', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.halted,
      );
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, joinParams),
        'Core lifetime status must be creation.',
      );
    });

    it('should fail when core status is corrupted', async () => {
      await consensus.setCoreLifetime(
        core.address,
        consensusUtil.CoreLifetime.halted,
      );
      await Utils.expectRevert(
        consensusUtil.joinDuringCreation(consensus, joinParams),
        'Core lifetime status must be creation.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should call joinDuringCreation with correct params', async () => {
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

      const spyValidator = await core.spyValidator.call();
      assert.strictEqual(
        spyValidator,
        joinParams.txOptions.from,
        'Validator address not set in spy core contract',
      );

      const spyCoreFromConsensusGateway = await consensusGateway.spyCore.call();
      assert.strictEqual(
        spyCoreFromConsensusGateway,
        core.address,
        'Core address not set in spy consensus gateway contract',
      );
      const spyFeeGasPriceFromConsensusGateway = new BN(
        await consensusGateway.spyFeeGasPrice.call(),
      );
      const feeGasPrice = new BN(await consensus.feeGasPrice.call());
      assert.strictEqual(
        spyFeeGasPriceFromConsensusGateway.toString(10),
        feeGasPrice.toString(10),
        'feeGasPrice is not set in spy consensus gateway contract',
      );

      const spyFeeGasLimitFromConsensusGateway = new BN(
        await consensusGateway.spyFeeGasLimit.call(),
      );
      const feeGasLimit = new BN(await consensus.feeGasLimit.call());
      assert.strictEqual(
        spyFeeGasLimitFromConsensusGateway.toString(10),
        feeGasLimit.toString(10),
        'feeGasLimit is not set in spy consensus gateway contract',
      );
    });
  });
});
