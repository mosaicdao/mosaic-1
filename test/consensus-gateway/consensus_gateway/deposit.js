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

const MockToken = artifacts.require('MockToken');
const ConsensusGateway = artifacts.require('ConsensusGateway');
const MockConsensus = artifacts.require('MockConsensus');

const { AccountProvider } = require('../../test_lib/utils.js');
const Utils = require('../../test_lib/utils.js');

contract('ConsensusGateway::deposit', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let param;
  let most;

  let consensusGateway;
  beforeEach(async () => {
    consensusGateway = await ConsensusGateway.new();
    const owner = accountProvider.get();
    most = await MockToken.new(18, { from: owner });
    param = {
      metachainId: Utils.getRandomHash(),
      mostAddress: most.address,
      owner,
      consensusCogateway: accountProvider.get(),
      stateRootProvider: accountProvider.get(),
      maxStorageRootItems: new BN(100),
      amount: new BN(100),
      beneficiary: accountProvider.get(),
      feeGasPrice: new BN(1),
      feeGasLimit: new BN(1),
    };

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
    await consensusGateway.setup(
      param.metachainId,
      consensus.address,
      param.mostAddress,
      param.consensusCogateway,
      param.maxStorageRootItems,
      new BN(1),
    );
  });

  it('should successfully deposit', async () => {
    const beforeMOSTBalanceConsensusGateway = await most.balanceOf(consensusGateway.address);
    const beforeMOSTBalanceDepositor = await most.balanceOf(param.owner);

    await most.approve(
      consensusGateway.address,
      param.amount,
      { from: param.owner },
    );

    const messageHash = await consensusGateway.deposit.call(
      param.amount,
      param.beneficiary,
      param.feeGasPrice,
      param.feeGasLimit,
    );

    await consensusGateway.deposit(
      param.amount,
      param.beneficiary,
      param.feeGasPrice,
      param.feeGasLimit,
    );

    const afterMOSTBalanceConsensusGateway = await most.balanceOf(consensusGateway.address);
    const afterMOSTBalanceDepositor = await most.balanceOf(param.owner);

    const messageStatus = await consensusGateway.outbox.call(messageHash);

    assert.isOk(messageStatus === true, 'Message status must be true');

    assert.isOk(
      afterMOSTBalanceConsensusGateway.eq(beforeMOSTBalanceConsensusGateway.add(param.amount)),
      'Deposit amount must be transferred to consensus gateway.'
       + ` Expected balance is ${beforeMOSTBalanceConsensusGateway.add(param.amount).toString(10)} but`
       + `found ${afterMOSTBalanceConsensusGateway.toString(10)}`,
    );

    assert.isOk(
      afterMOSTBalanceDepositor.eq(beforeMOSTBalanceDepositor.sub(param.amount)),
      'Deposit amount must be transferred from depositor.'
      + ` Expected balance is ${beforeMOSTBalanceDepositor.sub(param.amount).toString(10)} but`
      + `found ${afterMOSTBalanceDepositor.toString(10)}`,
    );
  });
});
