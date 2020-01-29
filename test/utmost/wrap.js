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

const Utmost = artifacts.require('UtmostTest');

const BN = require('bn.js');

const Utils = require('./../test_lib/utils');
const EventDecoder = require('./../test_lib/event_decoder.js');
const { AccountProvider } = require('../test_lib/utils.js');

contract('Utmost.wrap()', (accounts) => {
  let utmost;
  let initialSupply;
  let caller;
  let amountToWrap;
  let coconsensus;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    coconsensus = accountProvider.get();
    initialSupply = new BN('1000000');
    utmost = await Utmost.new(coconsensus, initialSupply);
    await utmost.setup({ from: coconsensus });
    caller = accountProvider.get();
    amountToWrap = new BN('100');
  });

  it('should wrap successfully with correct parameters ', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utmost.address);
    const initialCallerBaseCoinBalance = await Utils.getBalance(caller);

    const result = await utmost.wrap.call({
      from: caller, // Caller has gas initially from AccountProvider
      value: amountToWrap,
    });
    assert.strictEqual(
      result,
      true,
      'The contract should return true.',
    );

    const tx = await utmost.wrap({ from: caller, value: amountToWrap });
    const gasUsed = new BN(tx.receipt.gasUsed);

    const callerERC20TokenBalance = await utmost.balanceOf.call(
      caller,
    );
    assert.strictEqual(
      callerERC20TokenBalance.eq(amountToWrap),
      true,
      `The balance of ${caller} should match ${amountToWrap.toString(10)}.`,
    );

    const contractERC20TokenBalance = await utmost.balanceOf.call(
      utmost.address,
    );
    assert.strictEqual(
      contractERC20TokenBalance.eq(initialSupply.sub(amountToWrap)),
      true,
      `The balance of Utmost contract should be ${contractERC20TokenBalance.toString(10)}.`,
    );

    const finalContractBaseCoinBalance = await Utils.getBalance(utmost.address);
    const finalCallerBaseCoinBalance = await Utils.getBalance(caller);

    assert.strictEqual(
      finalContractBaseCoinBalance.eq(initialContractBaseCoinBalance.add(amountToWrap)),
      true,
      `Contract base coin balance should increase by ${amountToWrap}`,
    );

    assert.strictEqual(
      finalCallerBaseCoinBalance.eq(initialCallerBaseCoinBalance.sub(amountToWrap).sub(gasUsed)),
      true,
      `Caller's base coin balance should decrease by ${amountToWrap.sub(gasUsed).toString(10)}`,
    );
  });

  it('It should emit transfer event', async () => {
    const tx = await utmost.wrap({ from: caller, value: amountToWrap });
    const event = EventDecoder.getEvents(tx, utmost);
    assert.isDefined(event.Transfer, 'Event `Transfer` must be emitted.');
    const eventData = event.Transfer;

    assert.strictEqual(
      eventData._from,
      utmost.address,
      `The _from address in the event should be equal to ${utmost.address}`,
    );

    assert.strictEqual(
      eventData._to,
      caller,
      `The _to address in the event should be equal to ${caller}`,
    );

    assert.strictEqual(
      amountToWrap.eq(eventData._value),
      true,
      `The _value in the event should be equal to ${amountToWrap.toString(10)}`,
    );
  });
});
