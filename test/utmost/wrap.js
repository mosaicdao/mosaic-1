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
  let consensusCogateway;
  let initialSupply;
  let caller;
  let amount;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    utmost = await Utmost.new();
    consensusCogateway = accountProvider.get();
    initialSupply = new BN('1000000');
    await utmost.setup(
      initialSupply,
      consensusCogateway,
    );
    caller = accountProvider.get();
    amount = new BN('100');
    await utmost.setTokenBalance(utmost.address, amount);
  });

  it('should wrap successfully with correct parameters ', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utmost.address);
    const initialCallerBaseCoinBalance = await Utils.getBalance(caller);

    const result = await utmost.wrap.call({
      from: caller, // Caller has gas initially from AccountProvider
      value: amount,
    });
    assert.strictEqual(
      result,
      true,
      'The contract should return true.',
    );

    const tx = await utmost.wrap({ from: caller, value: amount });
    const gasUsed = new BN(tx.receipt.gasUsed);

    const callerERC20TokenBalance = await utmost.balanceOf.call(
      caller,
    );
    assert.strictEqual(
      callerERC20TokenBalance.eq(amount),
      true,
      `The balance of ${caller} should match ${amount.toString(10)}.`,
    );

    const contractERC20TokenBalance = await utmost.balanceOf.call(
      utmost.address,
    );
    assert.strictEqual(
      contractERC20TokenBalance.eqn(0),
      true,
      'The balance of Utmost contract should be zero.',
    );

    const finalContractBaseCoinBalance = await Utils.getBalance(utmost.address);
    const finalCallerBaseCoinBalance = await Utils.getBalance(caller);

    assert.strictEqual(
      finalContractBaseCoinBalance.eq(initialContractBaseCoinBalance.add(amount)),
      true,
      `Contract base coin balance should increase by ${amount}`,
    );

    assert.strictEqual(
      finalCallerBaseCoinBalance.eq(initialCallerBaseCoinBalance.sub(amount).sub(gasUsed)),
      true,
      `Caller's base coin balance should decrease by ${amount.sub(gasUsed).toString(10)}`,
    );
  });

  it('It should emit transfer event', async () => {
    const tx = await utmost.wrap({ from: caller, value: amount });
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
      amount.eq(eventData._value),
      true,
      `The _value in the event should be equal to ${amount.toString(10)}`,
    );
  });

  it('should emit token wrapped event', async () => {
    const tx = await utmost.wrap({ from: caller, value: amount });
    const event = EventDecoder.getEvents(tx, utmost);

    assert.isDefined(
      event.TokenWrapped,
      'Event `TokenWrapped` must be emitted.',
    );

    const eventData = event.TokenWrapped;
    assert.strictEqual(
      eventData._account,
      caller,
      `The _account address in the event should be equal to ${caller}`,
    );

    assert.strictEqual(
      amount.eq(eventData._amount),
      true,
      `The _amount in the event should be equal to ${amount.toString(10)}`,
    );
  });
});
