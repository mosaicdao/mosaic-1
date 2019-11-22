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

const ConsensusModule = artifacts.require('ConsensusModule');

contract('ConsensusModule::setupConsensus', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let consensusModule;
  let consensusAddress;
  beforeEach(async () => {
    consensusModule = await ConsensusModule.new();
    consensusAddress = accountProvider.get();
  });

  contract('Negative Tests', () => {
    it('should fail to set when consensus address is null', async () => {
      await consensusModule.setupConsensus(Utils.NULL_ADDRESS);
      await Utils.expectRevert(
        consensusModule.setupConsensus(consensusAddress),
        'Address must not be null.',
      );
    });

    it('should fail to set when consensus address is already set', async () => {
      await consensusModule.setupConsensus(consensusAddress);
      await Utils.expectRevert(
        consensusModule.setupConsensus(consensusAddress),
        'Consensus address is already present.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should set consensus address successfully', async () => {
      await consensusModule.setupConsensus(consensusAddress);
      const actualConsensusAddress = await consensusModule.consensus.call();
      assert.strictEqual(
        actualConsensusAddress,
        consensusAddress,
        'Incorrect consensus address',
      );
    });
  });
});
