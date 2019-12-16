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

const TestConsensusGatewayBase = artifacts.require('TestConsensusGatewayBase');

contract('ConsensusGatewayBase::setupConsensusGatewayBase', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let testConsensusGatewayBase;
  let consensusAddress;
  let mOstAddress;
  beforeEach(async () => {
    testConsensusGatewayBase = await TestConsensusGatewayBase.new();
    consensusAddress = accountProvider.get();
    mOstAddress = accountProvider.get();
  });

  contract('Positive Tests', () => {
    it('should set consensus and MOst contract addresses successfully', async () => {
      await testConsensusGatewayBase.callSetupConsensusGatewayBase(consensusAddress, mOstAddress);

      const actualConsensusAddress = await testConsensusGatewayBase.consensus.call();
      assert.strictEqual(
        actualConsensusAddress,
        consensusAddress,
        'Incorrect consensus contract address',
      );

      const actualMOstAddress = await testConsensusGatewayBase.most.call();
      assert.strictEqual(
        actualMOstAddress,
        mOstAddress,
        'Incorrect MOst contract address',
      );
    });
  });
});
