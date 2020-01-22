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

'use strict';

import shared, {Validator} from '../shared';
import Utils from '../Utils';

const FUNDING_AMOUNT_IN_ETH = '2';

describe('Key generations', async () => {
  it.skip('Key Generation and funding', async () => {
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

    const withdrawalAddress1 = web3.eth.accounts.create('withdrawal-1');
    const withdrawalAddress2 = web3.eth.accounts.create('withdrawal-2');
    const withdrawalAddress3 = web3.eth.accounts.create('withdrawal-3');
    const withdrawalAddress4 = web3.eth.accounts.create('withdrawal-4');
    const withdrawalAddress5 = web3.eth.accounts.create('withdrawal-5');
    web3.eth.accounts.wallet.add(techGov);
    web3.eth.accounts.wallet.add(validator1);
    web3.eth.accounts.wallet.add(validator2);
    web3.eth.accounts.wallet.add(validator3);
    web3.eth.accounts.wallet.add(validator4);
    web3.eth.accounts.wallet.add(validator5);

    web3.eth.accounts.wallet.add(withdrawalAddress1);
    web3.eth.accounts.wallet.add(withdrawalAddress2);
    web3.eth.accounts.wallet.add(withdrawalAddress3);
    web3.eth.accounts.wallet.add(withdrawalAddress4);
    web3.eth.accounts.wallet.add(withdrawalAddress5);

    const fundingRequest = [];
    const fundingAmount = web3.utils.toWei(FUNDING_AMOUNT_IN_ETH);

    fundingRequest.push(Utils.fundAddressForGas(techGov.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator1.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator2.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator3.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator4.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(validator5.address, funder, web3, fundingAmount));

    fundingRequest.push(Utils.fundAddressForGas(withdrawalAddress1.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(withdrawalAddress2.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(withdrawalAddress3.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(withdrawalAddress4.address, funder, web3, fundingAmount));
    fundingRequest.push(Utils.fundAddressForGas(withdrawalAddress5.address, funder, web3, fundingAmount));
    await Promise.all(fundingRequest);

    shared.origin.keys.techGov = techGov.address;
    shared.origin.keys.validators.push(new Validator(validator1.address, withdrawalAddress1.address));
    shared.origin.keys.validators.push(new Validator(validator2.address, withdrawalAddress2.address));
    shared.origin.keys.validators.push(new Validator(validator3.address, withdrawalAddress3.address));
    shared.origin.keys.validators.push(new Validator(validator4.address, withdrawalAddress4.address));
    shared.origin.keys.validators.push(new Validator(validator5.address, withdrawalAddress5.address));
  });
});
