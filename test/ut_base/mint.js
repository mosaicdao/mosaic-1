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
  let amountToBeMinted;
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
    amountToBeMinted = new BN('20');
    // Mints ERC20 UtBase balance for caller
    wrappedAmount = new BN('100');
    await utBase.wrap({ from: caller, value: wrappedAmount });
  });

  it('should mint base coins successfully', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const initialCallerBaseCoinBalance = await Utils.getBalance(caller);

    const tx = await utBase.mint(beneficiary, amountToBeMinted, { from: caller });
    const gasUsed = new BN(tx.receipt.gasUsed);

    const callerERC20TokenBalance = await utBase.balanceOf.call(
      caller,
    );
    assert.strictEqual(
      callerERC20TokenBalance.eq(wrappedAmount.sub(amountToBeMinted)),
      true,
      `The balance of ${caller} should be 80.`,
    );

    const contractERC20TokenBalance = await utBase.balanceOf.call(
      utBase.address,
    );
    assert.strictEqual(
      contractERC20TokenBalance.eq((initialSupply.sub(wrappedAmount)).add(amountToBeMinted)),
      true,
      `The token balance of UtBase contract should increase by ${amountToBeMinted.toString(10)}.`,
    );

    const finalContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const finalCallerBaseCoinBalance = await Utils.getBalance(caller);

    assert.strictEqual(
      finalContractBaseCoinBalance.eq(initialContractBaseCoinBalance.sub(amountToBeMinted)),
      true,
      `Contract base token balance should decrease by ${amountToBeMinted.toString(10)}`,
    );

    assert.strictEqual(
      finalCallerBaseCoinBalance.eq(initialCallerBaseCoinBalance.add(amountToBeMinted).sub(gasUsed)),
      true,
      `Caller's base coin balance should change by ${amountToBeMinted.sub(gasUsed).toString(10)}`,
    );
  });
});
