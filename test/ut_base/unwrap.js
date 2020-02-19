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
const EventDecoder = require('./../test_lib/event_decoder.js');
const { AccountProvider } = require('./../test_lib/utils');

contract('UtBase.unwrap()', (accounts) => {
  let utBase;
  let initialSupply;
  let caller;
  let wrappedAmount;
  let amountToUnwrap;
  let coconsensus;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    coconsensus = accountProvider.get();
    initialSupply = new BN('1000000');
    utBase = await UtBase.new(coconsensus, initialSupply);
    await utBase.setup({ from: coconsensus });
    caller = accountProvider.get();
    amountToUnwrap = new BN('20');
    // Mints ERC20 UtBase balance for caller
    wrappedAmount = new BN('100');
    await utBase.wrap({ from: caller, value: wrappedAmount });
  });

  it('should unwrap successfully with correct parameters', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const initialCallerBaseCoinBalance = await Utils.getBalance(caller);

    const tx = await utBase.unwrap(amountToUnwrap, { from: caller });
    const gasUsed = new BN(tx.receipt.gasUsed);

    const callerERC20TokenBalance = await utBase.balanceOf.call(
      caller,
    );
    assert.strictEqual(
      callerERC20TokenBalance.eq(wrappedAmount.sub(amountToUnwrap)),
      true,
      `The balance of ${caller} should be 80.`,
    );

    const contractERC20TokenBalance = await utBase.balanceOf.call(
      utBase.address,
    );
    assert.strictEqual(
      contractERC20TokenBalance.eq((initialSupply.sub(wrappedAmount)).add(amountToUnwrap)),
      true,
      `The token balance of UtBase contract should increase by ${amountToUnwrap.toString(10)}.`,
    );

    const finalContractBaseCoinBalance = await Utils.getBalance(utBase.address);
    const finalCallerBaseCoinBalance = await Utils.getBalance(caller);

    assert.strictEqual(
      finalContractBaseCoinBalance.eq(initialContractBaseCoinBalance.sub(amountToUnwrap)),
      true,
      `Contract base token balance should decrease by ${amountToUnwrap.toString(10)}`,
    );

    assert.strictEqual(
      finalCallerBaseCoinBalance.eq(initialCallerBaseCoinBalance.add(amountToUnwrap).sub(gasUsed)),
      true,
      `Caller's base coin balance should change by ${amountToUnwrap.sub(gasUsed).toString(10)}`,
    );
  });

  it('should emit transfer event', async () => {
    const tx = await utBase.unwrap(amountToUnwrap, { from: caller });
    const event = EventDecoder.getEvents(tx, utBase);

    assert.isDefined(event.Transfer, 'Event `Transfer` must be emitted.');

    const eventData = event.Transfer;

    assert.strictEqual(
      eventData._from,
      caller,
      `The _from address in the event should be equal to ${caller}`,
    );

    assert.strictEqual(
      eventData._to,
      utBase.address,
      `The _to address in the event should be equal to ${utBase.address}`,
    );

    assert.strictEqual(
      amountToUnwrap.eq(eventData._value),
      true,
      `The _value in the event should be equal to ${amountToUnwrap}`,
    );
  });
});
