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
const { AccountProvider } = require('./../test_lib/utils');

contract('Utmost.unwrap()', (accounts) => {
  let utmost;
  let consensusCogateway;
  let initialSupply;
  let caller;
  let amount;
  let amountToUnwrap;
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
    amountToUnwrap = new BN('20');
    await utmost.setTokenBalance(caller, amount);
    await utmost.initializeBaseCoinBalance(
      { from: caller, value: initialSupply },
    );
  });

  it('should unwrap successfully with correct parameters', async () => {
    const initialContractBaseCoinBalance = await Utils.getBalance(utmost.address);
    const initialCallerBaseCoinBalance = await Utils.getBalance(caller);

    const result = await utmost.unwrap.call(amountToUnwrap, {
      from: caller,
    });
    assert.strictEqual(result, true, 'The contract should return true.');

    const tx = await utmost.unwrap(amountToUnwrap, { from: caller });
    const gasUsed = new BN(tx.receipt.gasUsed);

    const callerERC20TokenBalance = await utmost.balanceOf.call(
      caller,
    );
    assert.strictEqual(
      callerERC20TokenBalance.eqn(80),
      true,
      `The balance of ${caller} should be 80.`,
    );

    const contractERC20TokenBalance = await utmost.balanceOf.call(
      utmost.address,
    );
    assert.strictEqual(
      contractERC20TokenBalance.eq(amountToUnwrap),
      true,
      `The balance of Utmost contract should increase by ${amountToUnwrap.toString(10)}.`,
    );

    const finalContractBaseCoinBalance = await Utils.getBalance(utmost.address);
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
    const tx = await utmost.unwrap(amountToUnwrap, { from: caller });
    const event = EventDecoder.getEvents(tx, utmost);

    assert.isDefined(event.Transfer, 'Event `Transfer` must be emitted.');

    const eventData = event.Transfer;

    assert.strictEqual(
      eventData._from,
      caller,
      `The _from address in the event should be equal to ${caller}`,
    );

    assert.strictEqual(
      eventData._to,
      utmost.address,
      `The _to address in the event should be equal to ${utmost.address}`,
    );

    assert.strictEqual(
      amountToUnwrap.eq(eventData._value),
      true,
      `The _value in the event should be equal to ${amountToUnwrap}`,
    );
  });

  it('should emit token unwrapped event', async () => {
    const tx = await utmost.unwrap(amountToUnwrap, { from: caller });

    const event = EventDecoder.getEvents(tx, utmost);

    assert.isDefined(
      event.TokenUnwrapped,
      'Event `TokenUnwrapped` must be emitted.',
    );

    const eventData = event.TokenUnwrapped;

    assert.strictEqual(
      eventData._account,
      caller,
      `The _account address in the event should be equal to ${caller}`,
    );

    assert.strictEqual(
      amountToUnwrap.eq(eventData._amount),
      true,
      `The _amount in the event should be equal to ${amountToUnwrap.toString(10)}`,
    );
  });
});
