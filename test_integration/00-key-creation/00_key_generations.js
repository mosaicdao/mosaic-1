// Copyright 2019 OpenST Ltd.
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
//
// ----------------------------------------------------------------------------
//
// http://www.simpletoken.org/
//
// ----------------------------------------------------------------------------

const shared = require('../shared');
const Utils = require('../Utils');

const FUNDING_AMOUNT_IN_ETH = '2';

describe('Key generations', async () => {
  it('Key Generation and funding', async () => {
    const { web3 } = shared.origin;

    const accounts = await web3.eth.getAccounts();
    const funder = accounts[0];
    shared.origin.funder = funder;
    const techGov = web3.eth.accounts.create('tech-gov');
    const validator1 = web3.eth.accounts.create('validator-1');
    const validator2 = web3.eth.accounts.create('validator-2');
    const validator3 = web3.eth.accounts.create('validator-3');
    const validator4 = web3.eth.accounts.create('validator-4');
    const validator5 = web3.eth.accounts.create('validator-5');

    web3.eth.accounts.wallet.add(techGov);
    web3.eth.accounts.wallet.add(validator1);
    web3.eth.accounts.wallet.add(validator2);
    web3.eth.accounts.wallet.add(validator3);
    web3.eth.accounts.wallet.add(validator4);
    web3.eth.accounts.wallet.add(validator5);

    const fundingRequest = [];
    const fundingAmount = web3.utils.toWei(FUNDING_AMOUNT_IN_ETH);

    fundingRequest.push(Utils.fundAddressForGas(techGov.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator1.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator2.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator3.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator4.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator5.address, funder, web3, fundingAmount));

    await Promise.all(fundingRequest);

    shared.origin.keys.techGov = techGov.address;
    shared.origin.keys.validators.push(validator1.address);
    shared.origin.keys.validators.push(validator2.address);
    shared.origin.keys.validators.push(validator3.address);
    shared.origin.keys.validators.push(validator4.address);
    shared.origin.keys.validators.push(validator5.address);
  });
});
