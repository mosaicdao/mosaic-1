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

import shared from '../shared';

const BN = require('bn.js');
const EventDecoder = require('../../../test/test_lib/event_decoder');

describe('Deposit and Confirm Deposit', async () => {

  let depositParam;
  let valueToken;
  let ERC20Gateway;
  let ERC20Cogateway;
  let depositMessageHash;

  before(async () => {
    ERC20Gateway = shared.contracts.ERC20Gateway;
    ERC20Cogateway = shared.contracts.ERC20Cogateway;
    valueToken = shared.contracts.ValueToken;

    depositParam = {
      amount: new BN(100),
      beneficiary: shared.accounts[7],
      feeGasPrice: new BN(1),
      feeGasLimit: new BN(100),
      valueToken: valueToken.address,
      depositor: shared.depositor,
    }
  });

  it('Deposit', async () => {

    await valueToken.instance.methods.approve(
      ERC20Gateway.address,
      depositParam.amount,
      { from: depositParam.depositor },
    );

    const depositorBalanceBeforeTransfer = await valueToken.balanceOf(depositParam.depositor);
    const erc20ContractBalanceBeforeTransfer = await valueToken.balanceOf(ERC20Gateway.address);

    console.log(" Before Depositor Balance ===>>", depositorBalanceBeforeTransfer);

    const tx = await ERC20Gateway.instance.methods.deposit(
      depositParam.amount,
      depositParam.beneficiary,
      depositParam.feeGasPrice,
      depositParam.feeGasLimit,
      depositParam.valueToken,
      { from: depositParam.depositor },
    );

    const event = EventDecoder.getEvents(tx, ERC20Gateway);

    depositParam.messageHash = event.DepositIntentDeclared.messageHash_;

    console.log("Message Hash__ ===>", depositParam.messageHash);

    const depositorBalanceAfterTransfer = await valueToken.balanceOf(depositParam.depositor);
    const erc20ContractBalanceAfterTransfer = await valueToken.balanceOf(ERC20Gateway.address);

    console.log("After Depositor Balance ==> ", depositorBalanceAfterTransfer);
  });

  it('Confirms deposit', async () => { });
});