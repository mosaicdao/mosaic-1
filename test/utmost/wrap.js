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

const web3 = require('./../test_lib/web3.js');
const Utils = require('./../test_lib/utils');
const EventDecoder = require('./../test_lib/event_decoder.js');
const { AccountProvider } = require('../test_lib/utils.js');

contract('OSTPrime.wrap()', (accounts) => {
  let utmost;
  let consensusCogateway;
  let initialSupply;
  let caller;
  let amount;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    utmost = await Utmost.new();
    consensusCogateway = accountProvider.get();
    initialSupply = new BN('100');
    await utmost.setup(
      initialSupply, consensusCogateway,
    );
    caller = AccountProvider.get();
    amount = new BN(100);
  });

  it('should pass with correct parameters ', async () => {
    const initialContractBalance = await Utils.getBalance(utmost.address);

    const initialCallerBalance = await Utils.getBalance(caller);

    const result = await ostPrime.wrap.call({
      from: callerAddress,
      value: amount,
    });

    assert.strictEqual(result, true, 'The contract should return true.');

    const tx = await ostPrime.wrap({ from: callerAddress, value: amount });
    const gasUsed = new BN(tx.receipt.gasUsed);

    const callerEIP20Tokenbalance = await ostPrime.balanceOf.call(
      callerAddress,
    );
    assert.strictEqual(
      callerEIP20Tokenbalance.eq(amount),
      true,
      `The balance of ${callerAddress} should increase by ${amount}.`,
    );

    const contractEIP20Tokenbalance = await ostPrime.balanceOf.call(
      ostPrime.address,
    );
    assert.strictEqual(
      contractEIP20Tokenbalance.eq(new BN(0)),
      true,
      'The balance of OST prime contract should be zero.',
    );

    const finalContractBalance = await Utils.getBalance(ostPrime.address);

    const finalCallerBalance = await Utils.getBalance(callerAddress);

    assert.strictEqual(
      finalContractBalance.eq(initialContractBalance.add(amount)),
      true,
      `Contract base token balance should increase by ${amount}`,
    );

    assert.strictEqual(
      finalCallerBalance.eq(initialCallerBalance.sub(amount).sub(gasUsed)),
      true,
      `Caller's base token balance should decrease by ${amount.sub(gasUsed)}`,
    );
  });

  it('should emit transfer event', async () => {
    await initialize();

    const tx = await ostPrime.wrap({ from: callerAddress, value: amount });

    const event = EventDecoder.getEvents(tx, ostPrime);

    assert.isDefined(event.Transfer, 'Event `Transfer` must be emitted.');

    const eventData = event.Transfer;

    assert.strictEqual(
      eventData._from,
      ostPrime.address,
      `The _from address in the event should be equal to ${ostPrime.address}`,
    );

    assert.strictEqual(
      eventData._to,
      callerAddress,
      `The _to address in the event should be equal to ${callerAddress}`,
    );

    assert.strictEqual(
      amount.eq(eventData._value),
      true,
      `The _value in the event should be equal to ${amount}`,
    );
  });

  it('should emit token wrapped event', async () => {
    await initialize();

    const tx = await ostPrime.wrap({ from: callerAddress, value: amount });

    const event = EventDecoder.getEvents(tx, ostPrime);

    assert.isDefined(
      event.TokenWrapped,
      'Event `TokenWrapped` must be emitted.',
    );

    const eventData = event.TokenWrapped;

    assert.strictEqual(
      eventData._account,
      callerAddress,
      `The _account address in the event should be equal to ${callerAddress}`,
    );

    assert.strictEqual(
      amount.eq(eventData._amount),
      true,
      `The _amount in the event should be equal to ${amount}`,
    );
  });
});
