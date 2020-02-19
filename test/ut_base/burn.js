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
const { AccountProvider } = require('../test_lib/utils');

contract('UtBase::burn', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  const consensusCogateway = accountProvider.get();
  const beneficiary = accountProvider.get();

  let initialSupply;
  let utBase;
  let amount;
  let coconsensus;
  let burnAmount;
  beforeEach(async () => {
    coconsensus = accountProvider.get();
    initialSupply = new BN('1000000');
    utBase = await UtBase.new(coconsensus, initialSupply);
    amount = new BN(10);
    burnAmount = new BN(5);
    await utBase.setup({ from: coconsensus });
    await utBase.setConsensusCogateway(consensusCogateway);
    await utBase.wrap({ from: beneficiary, value: amount });
  });

  it('should burn tokens when called with proper params', async () => {
    const balanceBeforeBurn = await utBase.balanceOf(beneficiary);
    const initialTotalTokenSupply = await utBase.getTotalTokenSupply();

    await utBase.burn(burnAmount, { from: beneficiary });

    const balanceAfterBurn = await utBase.balanceOf(beneficiary);

    assert.strictEqual(
      balanceBeforeBurn.sub(balanceAfterBurn).eq(burnAmount),
      true,
      `Balance of beneficiary must decrease by ${burnAmount.toString(10)}.`,
    );

    const finalTotalTokenSupply = await utBase.getTotalTokenSupply();
    assert.strictEqual(
      initialTotalTokenSupply.sub(burnAmount).eq(finalTotalTokenSupply),
      true,
      `Expected total supply after burning is ${(initialTotalTokenSupply.add(burnAmount)).toString(10)}`
      + ` but got ${finalTotalTokenSupply.toString(10)}`,
    );
  });
});
