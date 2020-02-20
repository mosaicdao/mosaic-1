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
const { AccountProvider } = require('../../test_lib/utils.js');
const TestData = require('../data/deposit_proof');

const SpyCoconsensus = artifacts.require('SpyCoconsensus');
const ConsensusCogateway = artifacts.require('ConsensusCogatewayDouble');
const UtBaseConfirmDepositSpy = artifacts.require('UtBaseConfirmDepositSpy');

contract('ConsensusCogateway::confirmDeposit', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let consensusCogateway;
  const anchor = accountProvider.get();
  let setupParams;
  let utBase;

  beforeEach(async () => {
    consensusCogateway = await ConsensusCogateway.new();

    await consensusCogateway.setValueToken(TestData.valueToken);

    utBase = await UtBaseConfirmDepositSpy.new();
    setupParams = {
      metachainId: TestData.metachainId,
      utBase: utBase.address,
      consensusGateway: TestData.consensusGateway,
      outboxStorageIndex: new BN(1),
      maxStorageRootItems: new BN(100),
      metablockHeight: new BN(1),
      coconsensus: await SpyCoconsensus.new(),
    };

    await setupParams.coconsensus.setAnchorAddress(setupParams.metachainId, anchor);

    await consensusCogateway.setup(
      setupParams.metachainId,
      setupParams.coconsensus.address,
      setupParams.utBase,
      setupParams.consensusGateway,
      setupParams.outboxStorageIndex,
      setupParams.maxStorageRootItems,
      setupParams.metablockHeight,
    );

    await consensusCogateway.setInboundChannelIdentifier(
      TestData.outboundChannelIdentifier,
    );

    await consensusCogateway.setStorageRoot(
      TestData.blockNumber,
      TestData.rawProofResult.storageHash,
    );
  });

  contract('Positive Tests', () => {
    it('should confirm deposit', async () => {
      const sender = accounts[2];
      await consensusCogateway.confirmDeposit(
        TestData.depositParam.amount,
        TestData.depositParam.beneficiary,
        TestData.depositParam.feeGasPrice,
        TestData.depositParam.feeGasLimit,
        TestData.depositParam.beneficiary,
        TestData.blockNumber,
        TestData.storageProof,
        { from: sender },
      );

      const beneficiary1 = await utBase.beneficiaries.call(0);
      const beneficiary2 = await utBase.beneficiaries.call(1);
      const amount1 = await utBase.amounts.call(0);
      const amount2 = await utBase.amounts.call(1);

      assert.strictEqual(
        beneficiary1,
        sender,
        'Reward should be minted for message sender',
      );
      assert.strictEqual(
        beneficiary2,
        TestData.depositParam.beneficiary,
        'Amount should be minted to beneficiary',
      );

      assert.isOk(
        new BN(TestData.depositParam.amount)
          .eq(
            new BN(amount1).add(new BN(amount2)),
          ),
        'Reward plus minted amount should be equal to deposit amount',
      );
    });
  });
});
