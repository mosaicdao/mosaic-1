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
  let consensusCogateway;
  let beneficiary;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    coconsensus = accountProvider.get();
    consensusCogateway = accountProvider.get();
    beneficiary = accountProvider.get();
    initialSupply = new BN('1000000');
    utBase = await UtBase.new(coconsensus, initialSupply);
    await utBase.setup({ from: coconsensus });
    await utBase.setConsensusCogateway(consensusCogateway);
    caller = accountProvider.get();
    mintedAmount = new BN('20');

    wrappedAmount = new BN('100');
    await utBase.wrap({ from: caller, value: wrappedAmount });
  });

  it('should mint base coins successfully', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const beneficiaryInitialERC20Balance = await utBase.balanceOf.call(beneficiary);
    const beneficiaryInitialCoinBalance = await Utils.getBalance(beneficiary);
    const initialTotalTokenSupply = await utBase.getTotalTokenSupply();

    await utBase.mint(beneficiary, mintedAmount, { from: consensusCogateway });

    const finalUtBaseContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const beneficiaryFinalCoinBalance = await Utils.getBalance(beneficiary);
    assert.strictEqual(
      initialContractBaseCoinBalance.sub(
        finalUtBaseContractBaseCoinBalance,
      ).eq(mintedAmount),
      true,
      `Contract base coin balance should decrease by ${mintedAmount.toString(10)}`,
    );

    const beneficiaryAfterERC20Balance = await utBase.balanceOf.call(beneficiary);
    assert.strictEqual(
      beneficiaryInitialERC20Balance.eq(beneficiaryAfterERC20Balance),
      true,
      `Expected beneficiary erc20 balance is ${beneficiaryInitialERC20Balance.toString(10)} `
      + `but got ${beneficiaryAfterERC20Balance.toString(10)}`,
    );

    assert.strictEqual(
      beneficiaryFinalCoinBalance.eq(beneficiaryInitialCoinBalance.add(mintedAmount)),
      true,
      'Expected base coin balance for beneficiary is '
      + `${(beneficiaryInitialCoinBalance.add(mintedAmount)).toString(10)} but`
      + ` got ${beneficiaryFinalCoinBalance.toString(10)}`,
    );

    const finalTotalTokenSupply = await utBase.getTotalTokenSupply();
    assert.strictEqual(
      initialTotalTokenSupply.add(mintedAmount).eq(finalTotalTokenSupply),
      true,
      'Expected total supply after minting is'
      + ` ${(initialTotalTokenSupply.add(mintedAmount)).toString(10)}`
      + ` but got ${finalTotalTokenSupply.toString(10)}`,
    );
  });
});
