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

const UtBase = artifacts.require('UtBaseTest');

const BN = require('bn.js');

const Utils = require('./../test_lib/utils');
const { AccountProvider } = require('./../test_lib/utils');

contract('UtBase.mint()', (accounts) => {
  let utBase;
  let initialSupply;
  let caller;
  let wrappedAmount;
  let mintedAmount;
  let coconsensus;
  let consensusCogateaway;
  let beneficiary;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    coconsensus = accountProvider.get();
    consensusCogateaway = accountProvider.get();
    beneficiary = accountProvider.get();
    initialSupply = new BN('1000000');
    utBase = await UtBase.new(coconsensus, initialSupply);
    await utBase.setup({ from: coconsensus });
    await utBase.setConsensusCogateway(consensusCogateaway);
    caller = accountProvider.get();
    mintedAmount = new BN('20');

    wrappedAmount = new BN('100');
    await utBase.wrap({ from: caller, value: wrappedAmount });
  });

  it('should mint base coins successfully', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const beneficiaryInitialERC20Balance = await utBase.balanceOf.call(beneficiary);

    await utBase.mint(beneficiary, mintedAmount, { from: consensusCogateaway });

    const finalUtBaseContractBaseCoinBalance = await Utils.getBalance(utBase.address);

    assert.strictEqual(
      initialContractBaseCoinBalance.sub(
        finalUtBaseContractBaseCoinBalance,
      ).eq(mintedAmount),
      true,
      `Expected base coin balance for UtBase contract is ${wrappedAmount.sub(mintedAmount)}`
        + `but got ${finalUtBaseContractBaseCoinBalance}`,
    );

    const beneficiaryAfterERC20Balance = await utBase.balanceOf.call(beneficiary);
    assert.strictEqual(
      beneficiaryInitialERC20Balance.eq(beneficiaryAfterERC20Balance),
      true,
      `Expected beneficiary erc20 balance is ${beneficiaryInitialERC20Balance} `
       + `but got ${beneficiaryAfterERC20Balance}`,
    );
  });
});
