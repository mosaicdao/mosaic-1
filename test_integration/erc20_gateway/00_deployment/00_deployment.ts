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

import shared from '../shared'
import Interacts from '../../../interacts/Interacts';

describe('Contract deployment', async (): Promise<void> => {

  it('Deploy value token', async (): Promise<void> => {

    shared.accounts = await shared.web3.eth.getAccounts();
    const depositor = shared.accounts[2];
    shared.depositor = depositor;
    shared.facilitator = shared.accounts[3];
    const valueToken = await shared.artifacts.ERC20Token.new(
      depositor,
      '8000000000000000000000',
    );
    const valueTokenAddress = valueToken.address;
    shared.contracts.ValueToken.instance = Interacts.getERC20I(shared.web3, valueTokenAddress);
    shared.contracts.ValueToken.address = valueTokenAddress;
  });

  it('Deploy anchors', async (): Promise<void> => {
    const originAnchor = await shared.artifacts.Anchor.new();
    const originAnchorAddress = originAnchor.address;
    shared.contracts.OriginAnchor.instance = Interacts.getAnchor(shared.web3, originAnchorAddress);
    shared.contracts.OriginAnchor.address = originAnchorAddress;

    const auxAnchor = await shared.artifacts.Anchor.new();
    const auxAnchorAddress = auxAnchor.address;
    shared.contracts.AuxilaryAnchor.instance = Interacts.getAnchor(shared.web3, auxAnchorAddress);
    shared.contracts.AuxilaryAnchor.address = auxAnchorAddress;
  });

  it('Deploy gateways', async (): Promise<void> => {
    const ERC20Gateway = await shared.artifacts.ERC20Gateway.new();
    const erc20GatewayAddress = ERC20Gateway.address;
    shared.contracts.ERC20Gateway.instance = Interacts.getERC20Gateway(shared.web3, erc20GatewayAddress);
    shared.contracts.ERC20Gateway.address = erc20GatewayAddress;

    const ERC20Cogateway = await shared.artifacts.ERC20Cogateway.new();
    const erc20CogatewayAddress = ERC20Cogateway.address;
    shared.contracts.ERC20Cogateway.instance = Interacts.getGen0ERC20Cogateway(shared.web3, erc20CogatewayAddress);
    shared.contracts.ERC20Cogateway.address = erc20CogatewayAddress;
  });
});
