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
const { AccountProvider } = require('../../test_lib/utils.js');
const TestData = require('../data/deposit_proof');

const SpyCoConsensus = artifacts.require('SpyCoConsensus');
const ConsensusCogateway = artifacts.require('ConsensusCogatewayTest');
const SpyUTMOST = artifacts.require('SpyUTMOST');

contract('ConsensusCoGateway::confirmDeposit', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let consensusCogateway;
  const anchor = accountProvider.get();
  let setupParams;

  beforeEach(async () => {
    consensusCogateway = await ConsensusCogateway.new();

    const utMOST = await SpyUTMOST.new();
    setupParams = {
      metachainId: TestData.metachainId,
      utMOST: utMOST.address,
      consensusGateway: TestData.consensusGateway,
      outboxStorageIndex: new BN(1),
      maxStorageRootItems: new BN(100),
      metablockHeight: new BN(1),
      coConsensus: await SpyCoConsensus.new(),
    };

    await setupParams.coConsensus.setAnchorAddress(setupParams.metachainId, anchor);

    await consensusCogateway.setup(
      setupParams.metachainId,
      setupParams.coConsensus.address,
      setupParams.utMOST,
      setupParams.consensusGateway,
      setupParams.outboxStorageIndex,
      setupParams.maxStorageRootItems,
      setupParams.metablockHeight,
    );

    await consensusCogateway.setStorageRoot(
      TestData.blockNumber,
      TestData.rawProofResult.storageHash,
    );
  });

  contract('Positive Tests', () => {
    it('should confirm deposit', async () => {
      await consensusCogateway.confirmDeposit(
        TestData.depositParam.amount,
        TestData.depositParam.beneficiary,
        TestData.depositParam.feeGasPrice,
        TestData.depositParam.feeGasLimit,
        TestData.depositParam.beneficiary,
        TestData.blockNumber,
        TestData.storageProof,
      );

    });
  });
});
