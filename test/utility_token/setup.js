/* global web3 */

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

const UtilityToken = artifacts.require('UtilityToken');
const BN = require('bn.js');

contract('UtilityToken::setup', (accounts) => {
  const TOKEN_SYMBOL = 'UT';
  const TOKEN_NAME = 'Utility Token';
  const TOKEN_DECIMALS = 18;
  const TOTAL_TOKEN_SUPPLY = new BN('1000');
  const consensusCogateway = accounts[2];
  const valueToken = accounts[3];

  let utilityToken;

  beforeEach(async () => {
    utilityToken = await UtilityToken.new();
  });

  it('should pass with correct parameters.', async () => {
    await utilityToken.setup(
      TOKEN_SYMBOL,
      TOKEN_NAME,
      TOKEN_DECIMALS,
      TOTAL_TOKEN_SUPPLY,
      consensusCogateway,
      valueToken,
    );

    assert.strictEqual(
      web3.utils.isAddress(utilityToken.address),
      true,
      'Utility token contract address must not be zero.',
    );

    const name = await utilityToken.name.call();
    assert.strictEqual(
      name,
      TOKEN_NAME,
      `Token name from contract must be equal to ${TOKEN_NAME}.`,
    );

    const symbol = await utilityToken.symbol();
    assert.strictEqual(
      symbol,
      TOKEN_SYMBOL,
      `Token symbol from contract must be equal to ${TOKEN_SYMBOL}.`,
    );

    const decimals = await utilityToken.decimals();
    assert.strictEqual(
      decimals.eqn(TOKEN_DECIMALS),
      true,
      `Token decimals from contract must be equal to ${TOKEN_DECIMALS}.`,
    );

    const totalSupply = await utilityToken.totalSupply();
    assert.strictEqual(
      totalSupply.eq(TOTAL_TOKEN_SUPPLY),
      true,
      'Token total supply from contract must be equal to zero.',
    );

    const consensusCogatewayAddress = await utilityToken.consensusCogateway();
    assert.strictEqual(
      consensusCogatewayAddress,
      consensusCogateway,
      `ConsensusCogateway address must be set to ${consensusCogateway}.`,
    );

    const actualValueTokenAddress = await utilityToken.valueToken.call();
    assert.strictEqual(
      valueToken,
      actualValueTokenAddress,
      'Value token address must match.',
    );
  });
});
