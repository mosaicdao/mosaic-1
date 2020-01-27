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

const Utmost = artifacts.require('Utmost');
const BN = require('bn.js');
const web3 = require('./../test_lib/web3');

const { AccountProvider } = require('../test_lib/utils.js');

contract('UtilityToken::setup', (accounts) => {
  let utmost;
  let consensusCogateway;
  let initialSupply;
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    utmost = await Utmost.new();
    consensusCogateway = accountProvider.get();
    initialSupply = new BN('100');
  });

  it('should setup Utmost token correctly.', async () => {
    await utmost.setup(
      initialSupply,
      consensusCogateway,
    );

    assert.strictEqual(
      web3.utils.isAddress(utmost.address),
      true,
      'Utmost token contract address must not be zero.',
    );

    const name = await utmost.name.call();
    assert.strictEqual(
      name,
      'Utmost Token name from contract must be equal to Utmost.',
    );

    const symbol = await utmost.symbol();
    assert.strictEqual(
      symbol,
      'UT',
      'Token symbol from contract must be equal to UT.',
    );

    const decimals = await utmost.decimals();
    assert.strictEqual(
      decimals.eqn(new BN('18')),
      true,
      'Token decimals from contract must be equal to 18.',
    );

    const genesisTotalSupply = await utmost.genesisTotalSupply();
    assert.strictEqual(
      genesisTotalSupply.eq(initialSupply),
      true,
      `Token total supply from contract must be equal to ${initialSupply.toString(10)}.`,
    );

    const consensusCogatewayAddress = await utmost.consensusCogateway();
    assert.strictEqual(
      consensusCogatewayAddress,
      consensusCogateway,
      `ConsensusCogateway address must be set to ${consensusCogateway}.`,
    );
  });
});
