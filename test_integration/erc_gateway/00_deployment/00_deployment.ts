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

describe('Contract deployment', async () => {

  it('Deploy value token', async () => {

    const accounts = await shared.web3.eth.getAccounts();
    const depositor = accounts[2];
    const facilitator = accounts[3];
    shared.depositor = depositor;
    shared.facilitator = facilitator;
    const valueToken = await shared.artifacts.ERC20Token.new(
        depositor,
      '8000000000000000000000'
    );
    const valueTokenAddress = valueToken.address;
    shared.contracts.ValueToken.instance = Interacts.getERC20I(shared.web3, valueTokenAddress);
    shared.contracts.ValueToken.address = valueTokenAddress;
  });

  it('Deploy anchor', async () => {

  });

  it('Deploy gateway', async () => {

  });

});
