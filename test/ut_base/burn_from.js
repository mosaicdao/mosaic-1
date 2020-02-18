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

contract('UtBase::burnFrom', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  const consensusCogateway = accountProvider.get();
  const beneficiary = accountProvider.get();
  const spender = accountProvider.get();

  let utBase;
  let amount;
  const initialSupply = new BN(1000000);
  let burnAmount;
  beforeEach(async () => {
    const coconsensus = accountProvider.get();
    utBase = await UtBase.new(coconsensus, initialSupply);
    amount = new BN(10);
    burnAmount = new BN(5);
    await utBase.setup({ from: coconsensus });
    await utBase.setConsensusCogateway(consensusCogateway);
    await utBase.wrap({ from: beneficiary, value: amount });

    await utBase.approve(
      spender,
      burnAmount,
      {
        from: beneficiary,
      },
    );
  });

  it('should burn tokens', async () => {
    const balanceBeforeBurnFrom = await utBase.balanceOf(beneficiary);
    const initialTotalTokenSupply = await utBase.getTotalTokenSupply();

    await utBase.burnFrom(beneficiary, burnAmount, {
      from: spender,
    });

    const balanceAfterBurnFrom = await utBase.balanceOf(beneficiary);

    assert.strictEqual(
      balanceBeforeBurnFrom.sub(balanceAfterBurnFrom).eq(burnAmount),
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
