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

const ERC20Gateway = artifacts.require('ERC20Gateway');

const { AccountProvider } = require('../../test_lib/utils.js');
const HashDepositIntent = require('../../consensus-gateway/consensus_gateway_base/utils.js');

const MessageBusUtils = require('../../message_bus/messagebus_utils');
const Utils = require('../../test_lib/utils');

contract('ERC20Gateway::deposit', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let erc20Gateway;
  let erc20Cogateway;
  let stateRootProvider;
  let setupParam;
  let valueToken;
  let depositor;
  let param;

  beforeEach(async () => {
    erc20Gateway = await ERC20Gateway.new();
    erc20Cogateway = accountProvider.get();
    stateRootProvider = accountProvider.get();

    depositor = accountProvider.get();
    valueToken = await Utils.deployMockToken(depositor, 200);

    console.log('ValueToken address :-', valueToken.address);


    param = {
      valueToken: valueToken.address,
      amount: new BN(100),
      beneficiary: accountProvider.get(),
      feeGasPrice: new BN(1),
      feeGasLimit: new BN(1),
    };

    setupParam = {
      metachainId: Utils.getRandomHash(),
      erc20Cogateway,
      stateRootProvider,
      maxStorageRootItems: new BN(50),
      coGatewayOutboxIndex: new BN(1),
    };

    await erc20Gateway.setup(
      setupParam.metachainId,
      setupParam.erc20Cogateway,
      setupParam.stateRootProvider,
      setupParam.maxStorageRootItems,
      setupParam.coGatewayOutboxIndex,
    );
  });

  contract('Positive Tests', async () => {
    it('should successfully deposit the value token', async () => {
      await valueToken.approve(
        erc20Gateway.address,
        param.amount,
        { from: depositor },
      );

      const depositorBalanceBeforeTransfer = await valueToken.balanceOf(depositor);
      const erc20ContractBalanceBeforeTransfer = await valueToken.balanceOf(erc20Gateway.address);

      const actualMessageHash = await erc20Gateway.deposit.call(
        param.valueToken,
        param.amount,
        param.beneficiary,
        param.feeGasPrice,
        param.feeGasLimit,
        { from: depositor },
      );

      const channelIdentifier = await erc20Gateway.outboundChannelIdentifier.call();

      const depositIntentHash = HashDepositIntent.getDepositIntentHash(
        param.valueToken,
        param.amount,
        param.beneficiary,
      );

      const calculatedMessageHash = MessageBusUtils.hashMessage(
        depositIntentHash,
        new BN(0),
        param.feeGasPrice,
        param.feeGasLimit,
        depositor,
        channelIdentifier,
      );

      await erc20Gateway.deposit(
        param.valueToken,
        param.amount,
        param.beneficiary,
        param.feeGasPrice,
        param.feeGasLimit,
        { from: depositor },
      );

      const depositorBalanceAfterTransfer = await valueToken.balanceOf(depositor);
      const erc20ContractBalanceAfterTransfer = await valueToken.balanceOf(erc20Gateway.address);

      assert.isOk(
        depositorBalanceAfterTransfer.eq(depositorBalanceBeforeTransfer.sub(param.amount)),
        'Deposit amount must be transferred from depositor.'
      + ` Expected balance is ${depositorBalanceBeforeTransfer.sub(param.amount).toString(10)} but`
      + `found ${depositorBalanceAfterTransfer.toString(10)}`,
      );

      assert.isOk(
        erc20ContractBalanceAfterTransfer.eq(erc20ContractBalanceBeforeTransfer.add(param.amount)),
        'Deposit amount must be transferred to ERC20Gateway.'
      + ` Expected balance is ${erc20ContractBalanceBeforeTransfer.add(param.amount).toString(10)} but`
      + `found ${depositorBalanceAfterTransfer.toString(10)}`,
      );

      assert.strictEqual(
        actualMessageHash,
        calculatedMessageHash,
        'Actual message hash must match with calculated message hash.'
      + `Expected message hash is ${calculatedMessageHash}`
      + `found ${actualMessageHash}`,
      );
    });
  });
});
