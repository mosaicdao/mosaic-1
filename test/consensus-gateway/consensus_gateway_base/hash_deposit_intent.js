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

const ERC20GatewayBase = artifacts.require('ERC20GatewayBase');
const ConsensusGatewayUtils = require('./utils');
const Utils = require('../../test_lib/utils.js');
const { AccountProvider } = require('../../test_lib/utils.js');

contract('ERC20GatewayBase::hashDepositIntent', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let erc20GatewayBase;

  beforeEach(async () => {
    erc20GatewayBase = await ERC20GatewayBase.new();
  });

  it('should return correct hash', async () => {
    const amount = new BN(Utils.getRandomNumber(500));
    const beneficiary = accountProvider.get();

    const actualHashDepositIntent = await erc20GatewayBase.hashDepositIntent.call(
      amount,
      beneficiary,
    );

    const expectedDepositIntent = ConsensusGatewayUtils.getDepositIntentHash(amount, beneficiary);
    assert.strictEqual(
      actualHashDepositIntent,
      expectedDepositIntent,
      'Invalid deposit intent hash',
    );
  });

  it('verify DEPOSIT_INTENT_TYPEHASH', async () => {
    const actualDepositIntentTypeHash = await erc20GatewayBase.DEPOSIT_INTENT_TYPEHASH.call();

    assert.strictEqual(
      actualDepositIntentTypeHash,
      ConsensusGatewayUtils.DEPOSIT_INTENT_TYPEHASH,
      'Invalid deposit intent typehash',
    );
  });
});
