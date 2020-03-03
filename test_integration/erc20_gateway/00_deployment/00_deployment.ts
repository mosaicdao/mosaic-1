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

const assert = require('assert');

import shared from '../shared'
import Interacts from '../../../interacts/Interacts';
import BN = require('bn.js');

describe('Contract deployment', async (): Promise<void> => {

  it('Deploy value token', async (): Promise<void> => {
    shared.totalTokenSupply = new BN('8000000000000000000000');
    shared.accounts = await shared.web3.eth.getAccounts();
    shared.depositor = shared.accounts[2];
    shared.facilitator = shared.accounts[3];
    const valueToken = await shared.artifacts.ERC20Token.new(
      shared.depositor,
      shared.totalTokenSupply.toString(10),
    );
    const valueTokenAddress = valueToken.address;
    shared.contracts.ValueToken.instance = Interacts.getERC20I(shared.web3, valueTokenAddress);
    shared.contracts.ValueToken.address = valueTokenAddress;

    const depositorInitialBalance = await shared.contracts.ValueToken.instance.methods.balanceOf(
      shared.depositor,
    ).call();

    assert.strictEqual(
      shared.totalTokenSupply.eq(new BN(depositorInitialBalance)),
      true,
      `Depositor initial balance must be ${shared.totalTokenSupply.toString(10)} `
      + `but got ${depositorInitialBalance}`,
    );
  });

  it('Deploy anchors', async (): Promise<void> => {
    const originAnchor = await shared.artifacts.Anchor.new();
    assert.strictEqual(
      originAnchor && originAnchor.address !== null,
      true,
      'Origin anchor contract address must exists',
    );

    shared.contracts.OriginAnchor.instance = Interacts.getAnchor(
      shared.web3,
      originAnchor.address,
    );
    shared.contracts.OriginAnchor.address = originAnchor.address;

    const auxAnchor = await shared.artifacts.Anchor.new();
    assert.strictEqual(
      auxAnchor && auxAnchor.address !== null,
      true,
      'Auxiliary anchor contract address must exists',
    );

    const auxAnchorAddress = auxAnchor.address;
    shared.contracts.AuxilaryAnchor.instance = Interacts.getAnchor(shared.web3, auxAnchorAddress);
    shared.contracts.AuxilaryAnchor.address = auxAnchorAddress;
  });

  it('Deploy gateways', async (): Promise<void> => {
    const erc20Gateway = await shared.artifacts.ERC20Gateway.new();
    assert.strictEqual(
      erc20Gateway && erc20Gateway.address !== null,
      true,
      'ERC20Gateway contract address must exists',
    );

    shared.contracts.ERC20Gateway.instance = Interacts.getERC20Gateway(shared.web3, erc20Gateway.address);
    shared.contracts.ERC20Gateway.address = erc20Gateway.address;

    const erc20Cogateway = await shared.artifacts.ERC20Cogateway.new();
    assert.strictEqual(
      erc20Cogateway && erc20Cogateway.address !== null,
      true,
      'ERC20Cogateway contract address must exists',
    );

    shared.contracts.ERC20Cogateway.instance = Interacts.getGen0ERC20Cogateway(
      shared.web3,
      erc20Cogateway.address,
    );
    shared.contracts.ERC20Cogateway.address = erc20Cogateway.address;
  });
});
