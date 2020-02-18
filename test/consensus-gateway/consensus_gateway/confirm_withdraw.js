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
const TestData = require('../data/withdraw_proof');
const Utils = require('../../test_lib/utils.js');

const SpyConsensus = artifacts.require('SpyConsensus');
const ConsensusGateway = artifacts.require('ConsensusGatewayDouble');

contract('ConsensusGateway::confirmWithdraw', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let consensusGateway;
  let spyConsensus;
  let setupParams;
  let most;

  beforeEach(async () => {
    consensusGateway = await ConsensusGateway.new();
    const owner = accountProvider.get();
    most = await Utils.deployMockToken(owner);
    await most.transfer(
      consensusGateway.address,
      TestData.withdrawParam.amount,
      { from :owner, }
    );

    spyConsensus = await SpyConsensus.new();
    setupParams = {
      metachainId: TestData.metachainId,
      consensus: spyConsensus.address,
      most: most.address,
      consensusCogateway: TestData.consensusCogateway,
      maxStorageRootItems: new BN(100),
      outboxStorageIndex: new BN(1),
     };

     await consensusGateway.setup(
      setupParams.metachainId,
      setupParams.consensus,
      setupParams.most,
      setupParams.consensusCogateway,
      setupParams.maxStorageRootItems,
      setupParams.outboxStorageIndex,
     );

     await consensusGateway.setInboundChannelIdentifier(
      TestData.outboundChannelIdentifier,
     );

     await consensusGateway.setStorageRoot(
      TestData.blockNumber,
      TestData.rawProofResult.storageHash,
     );
  });

  contract('Positive Tests', () => {
    it('should confirm withdraw', async () => {
      const sender = accountProvider.get();
      let beforeMOSTBalanceConsensusGateway = await most.balanceOf(consensusGateway.address);
      let beforeMOSTBalanceWithdrawer = await most.balanceOf(TestData.withdrawParam.beneficiary);
      let beforeMOSTBalanceSender = await most.balanceOf(sender);

      await consensusGateway.confirmWithdraw(
        TestData.withdrawParam.amount,
        TestData.withdrawParam.beneficiary,
        TestData.withdrawParam.feeGasPrice,
        TestData.withdrawParam.feeGasLimit,
        TestData.withdrawParam.beneficiary,
        TestData.blockNumber,
        TestData.storageProof,
        {from : sender},
      );

      let afterMOSTBalanceConsensusGateway = await most.balanceOf(consensusGateway.address);
      let afterMOSTBalanceWithdrawer = await most.balanceOf(TestData.withdrawParam.beneficiary);
      let afterMOSTBalanceSender = await most.balanceOf(sender);

      let transactionMOSTBalanceWithdrawer = new BN(afterMOSTBalanceWithdrawer).sub(new BN(beforeMOSTBalanceWithdrawer));
      let transactionMOSTBalanceSender = new BN(afterMOSTBalanceSender).sub(new BN(beforeMOSTBalanceSender));

      assert.isOk(
        new BN(TestData.withdrawParam.amount)
        .eq(
          transactionMOSTBalanceWithdrawer.add(transactionMOSTBalanceSender),
        ),
        'Reward plus transfer amount should be equal to withdraw amount',
      );

      assert.isOk(
        new BN(TestData.withdrawParam.amount)
        .eq(
          new BN(beforeMOSTBalanceConsensusGateway).sub(new BN(afterMOSTBalanceConsensusGateway))
        ),
        'Withdrawal Amount should be transferred by consensus gateway.'
      );
    });
  });
});
