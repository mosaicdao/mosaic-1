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

const ConsensusGateway = artifacts.require('ConsensusGatewayTest');
const SpyCore = artifacts.require('SpyCore');

const { AccountProvider } = require('../../test_lib/utils.js');

contract('ConsensusGateway::declareOpenKernel', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let consensusGateway;
  let consensus;
  let spyCore;

  beforeEach(async () => {
    consensusGateway = await ConsensusGateway.new();
    spyCore = await SpyCore.new();
    consensus = accountProvider.get();
    await consensusGateway.setConsensus(consensus);
  });

  it('should declare open kernel', async () => {
    const feeGasPrice = new BN(0);
    const feeGasLimit = new BN(0);
    const txOptions = {
      from: consensus,
    };
    const messageHash = await consensusGateway.declareOpenKernel.call(
      spyCore.address,
      feeGasPrice,
      feeGasLimit,
      txOptions,
    );

    await consensusGateway.declareOpenKernel(
      spyCore.address,
      feeGasPrice,
      feeGasLimit,
      txOptions,
    );

    const outboxValue = await consensusGateway.outbox.call(messageHash);
    assert.strictEqual(
      outboxValue,
      true,
      'Outbox value is not true',
    );

    const currentMetablockHeight = new BN(
      await consensusGateway.currentMetablockHeight.call(),
    );
    const returnObject = await spyCore.getOpenKernel.call();
    assert.strictEqual(
      currentMetablockHeight.toString(10),
      (new BN(returnObject.openKernelHeight_)).toString(10),
      'Invalid current Metablock height value.',
    );

    const consensusNonce = new BN(
      await consensusGateway.outboxNonces.call(consensus),
    );
    assert.strictEqual(
      consensusNonce.toString(10),
      '1',
      'Invalid nonce value.',
    );
  });
});
