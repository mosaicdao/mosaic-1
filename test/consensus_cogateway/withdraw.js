// Copyright 2020 OpenST Ltd.
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

const ConsensusCogateway = artifacts.require('ConsensusCogateway');
const MockConsensus = artifacts.require('MockConsensus');

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

contract('ConsensusCogateway::withdraw', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let param;
  let utBase;

  let consensusCogateway;
  beforeEach(async () => {
    consensusCogateway = await ConsensusCogateway.new();
    param = {
      metachainId: Utils.getRandomHash(),
      owner: accountProvider.get(),
      consensusGateway: accountProvider.get(),
      stateRootProvider: accountProvider.get(),
      maxStorageRootItems: new BN(100),
      amount: new BN(100),
      beneficiary: accountProvider.get(),
      feeGasPrice: new BN(1),
      feeGasLimit: new BN(1),
    };

    utBase = await Utils.deployMockToken(param.owner);
    param.utBaseAddress = utBase.address;

    const consensusConfig = {
      metachainId: param.metachainId,
      epochLength: new BN(100),
      minValidatorCount: new BN(5),
      validatorJoinLimit: new BN(20),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(10),
      dynasty: new BN(0),
      accumulatedGas: new BN(1),
      sourceBlockHeight: new BN(0),
    };

    const consensus = await MockConsensus.new(
      consensusConfig.metachainId,
      consensusConfig.epochLength,
      consensusConfig.minValidatorCount,
      consensusConfig.validatorJoinLimit,
      consensusConfig.height,
      consensusConfig.parent,
      consensusConfig.gasTarget,
      consensusConfig.dynasty,
      consensusConfig.accumulatedGas,
      consensusConfig.sourceBlockHeight,
    );

    await consensusCogateway.setup(
      param.metachainId,
      consensus.address,
      param.utBaseAddress,
      param.consensusGateway,
      new BN(4),
      param.maxStorageRootItems,
      new BN(1),
    );
  });

  it('should successfully withdraw', async () => {
    const beforeutBaseBalanceWithdrawer = await utBase.balanceOf(param.owner);

    await utBase.approve(consensusCogateway.address, param.amount, {
      from: param.owner,
    });

    const messageHash = await consensusCogateway.withdraw.call(
      param.amount,
      param.beneficiary,
      param.feeGasPrice,
      param.feeGasLimit,
    );

    await consensusCogateway.withdraw(
      param.amount,
      param.beneficiary,
      param.feeGasPrice,
      param.feeGasLimit,
    );

    const afterUtBaseBalanceWithdrawer = await utBase.balanceOf(param.owner);

    const messageStatus = await consensusCogateway.outbox.call(messageHash);

    assert.isOk(messageStatus === true, 'Message status must be true');

    assert.isOk(
      afterUtBaseBalanceWithdrawer.eq(
        beforeutBaseBalanceWithdrawer.sub(param.amount),
      ),
      'Deposit amount must be transferred from redeemer.'
        + ` Expected balance is ${beforeutBaseBalanceWithdrawer
          .sub(param.amount)
          .toString(10)} but`
        + `found ${afterUtBaseBalanceWithdrawer.toString(10)}`,
    );
  });
});
