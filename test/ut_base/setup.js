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

const { AccountProvider } = require('../test_lib/utils.js');

contract('UtBase::setup', (accounts) => {
  let utBase;
  let consensusCogateway;
  let initialSupply;
  let coconsensus;

  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    coconsensus = accountProvider.get();
    initialSupply = new BN('1000000');
    // consensusCogateway
    utBase = await UtBase.new(coconsensus, initialSupply);
    consensusCogateway = '0x0000000000000000000000000000000000004d02';
  });

  it('should setup utBase token correctly.', async () => {
    await utBase.setup({ from: coconsensus });

    const name = await utBase.name.call();
    assert.strictEqual(
      name,
      'UtBase',
      'UtBase Token name from contract must be equal to UtBase.',
    );

    const symbol = await utBase.symbol();
    assert.strictEqual(
      symbol,
      'UB',
      'Token symbol from contract must be equal to UB.',
    );

    const decimals = await utBase.decimals();
    assert.strictEqual(
      decimals.eqn(18),
      true,
      'Token decimals from contract must be equal to 18.',
    );

    const genesisTotalSupply = await utBase.genesisTotalSupply();
    assert.strictEqual(
      genesisTotalSupply.eq(initialSupply),
      true,
      `Token total supply from contract must be equal to ${initialSupply.toString(10)}.`,
    );
  });
});
