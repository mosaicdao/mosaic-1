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

const UtilityToken = artifacts.require('UtilityTokenTest');
const BN = require('bn.js');

contract('UtBase::burnFrom', (accounts) => {
  const TOKEN_SYMBOL = 'UT';
  const TOKEN_NAME = 'Utility Token';
  const TOKEN_DECIMALS = 18;
  const TOTAL_TOKEN_SUPPLY = new BN('1000');
  const consensusCogateway = accounts[2];
  const beneficiary = accounts[3];
  const spender = accounts[4];

  let utilityToken;
  let amount;

  beforeEach(async () => {
    utilityToken = await UtilityToken.new();
    amount = new BN('100');

    await utilityToken.setupToken(
      TOKEN_SYMBOL,
      TOKEN_NAME,
      TOKEN_DECIMALS,
      TOTAL_TOKEN_SUPPLY,
      consensusCogateway,
    );

    await utilityToken.mint(
      beneficiary,
      amount,
      {
        from: consensusCogateway,
      },
    );

    await utilityToken.approve(
      spender,
      amount,
      {
        from: beneficiary,
      },
    );
  });

  it('should burn tokens from beneficiary when called with proper params by spender using burnFrom.', async () => {
    const balanceBeforeBurnFrom = await utilityToken.balanceOf(beneficiary);

    await utilityToken.burnFrom(beneficiary, amount, {
      from: spender,
    });

    const balanceAfterBurnFrom = await utilityToken.balanceOf(beneficiary);

    assert.strictEqual(
      balanceBeforeBurnFrom.sub(balanceAfterBurnFrom).eq(amount),
      true,
      `Balance of beneficiary must decrease by ${amount}.`,
    );
  });
});
