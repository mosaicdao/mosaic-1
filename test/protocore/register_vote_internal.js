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

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const ProtocoreUtils = require('./utils.js');

const TestProtocore = artifacts.require('TestProtocore');

const config = {};

contract('Protocore::registerVoteInternal', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.coconsensusAddress = accountProvider.get();
    config.domainSeparator = Utils.getRandomHash();
    config.epochLength = new BN(100);
    config.metachainId = Utils.getRandomHash();

    config.genesisKernelHeight = new BN(1);
    config.genesisKernelHash = Utils.getRandomHash();
    config.genesisParentVoteMessageHash = Utils.getRandomHash();
    config.genesisSourceTransitionHash = Utils.getRandomHash();
    config.genesisSourceBlockHash = Utils.getRandomHash();
    config.genesisTargetBlockHash = Utils.getRandomHash();
    config.genesisSourceBlockNumber = new BN(0);
    config.genesisTargetBlockNumber = new BN(config.epochLength);
    config.genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
      config.domainSeparator,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
    );
    config.genesisProposedMetablockHeight = new BN(1);

    config.protocore = await TestProtocore.new(
      config.coconsensusAddress,
      config.metachainId,
      config.domainSeparator,
      config.epochLength,
      config.genesisKernelHeight,
      config.genesisKernelHash,
      config.genesisParentVoteMessageHash,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
      config.genesisProposedMetablockHeight,
    );
  });

  contract('Negative Tests', async () => {
    it('should fail if a link mapping to the vote message hash does not exist', async () => {
    });
    it('should fail if a finalisation status of a target checkpoint '
    + 'is less than registered', async () => {
    });
    it('should fail if a link height inclusion principle is not kept', async () => {
    });
    it('should fail if a validator has already voted for a height', async () => {
    });
  });

  contract('Positive Tests', async () => {
    it('checks that a validator vote is stored', async () => {
    });
    it('checks that a vote of a validator from the forward validator set is counted', async () => {
    });
    it('checks that a vote of a validator from the rear validator set is counted', async () => {
    });
    it('checks that a vote of a validator is not double-counting', async () => {
    });
    it('checks that if a quorum reached link is justified', async () => {
    });
    it('checks that if a quorum reached a finalisation link is marked as finalised '
    + 'and coconsensus is notified', async () => {
    });
  });
});
