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

const BN = require('bn.js');
const Utils = require('../../test_lib/utils.js');
const { AccountProvider } = require('../../test_lib/utils.js');
const ConsensusGatewayUtils = require('../../consensus-gateway/utils');

const Gen0ERC20Cogateway = artifacts.require('Gen0ERC20Cogateway');

contract('Gen0ERC20Cogateway::activate', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let gen0ERC20Cogateway;
  let activateParams;

  beforeEach(async () => {
    gen0ERC20Cogateway = await Gen0ERC20Cogateway.new();
    activateParams = {
      metachainId: Utils.generateRandomMetachainId(),
      erc20Gateway: accountProvider.get(),
      stateRootProvider: accountProvider.get(),
      maxStorageRootItems: new BN(100),
      outboxStorageIndex: new BN(4),
    };
  });

  it('should successfully activate gen0 ERC20Cogateway', async () => {
    await gen0ERC20Cogateway.activate(
      activateParams.metachainId,
      activateParams.erc20Gateway,
      activateParams.stateRootProvider,
      activateParams.maxStorageRootItems,
      activateParams.outboxStorageIndex,
    );

    const outboxStorageIndexInContract = await gen0ERC20Cogateway.outboxStorageIndex.call();
    assert.isOk(
      activateParams.outboxStorageIndex.eq(outboxStorageIndexInContract),
      'Expected outbox storage index is '
      + `${activateParams.outboxStorageIndex.toString(10)}`
      + `but got ${outboxStorageIndexInContract.toString(10)}`,
    );

    const stateRootProviderInContract = await gen0ERC20Cogateway.stateRootProvider.call();
    assert.strictEqual(
      stateRootProviderInContract,
      activateParams.stateRootProvider,
      'State root provider address is not set in the contract.',
    );

    const messageInboxAddressFromContract = await gen0ERC20Cogateway.messageInbox.call();
    assert.strictEqual(
      messageInboxAddressFromContract,
      activateParams.erc20Gateway,
      'Inbox address is not set in the contract.',
    );

    const messageOutboxAddressFromContract = await gen0ERC20Cogateway.messageOutbox.call();
    assert.strictEqual(
      messageOutboxAddressFromContract,
      activateParams.erc20Gateway,
      'Outbox address is not set in the contract.',
    );

    const outboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
      activateParams.metachainId,
      gen0ERC20Cogateway.address,
      activateParams.erc20Gateway,
    );

    const outboundChannelIdentifierInContract = await gen0ERC20Cogateway.outboundChannelIdentifier
      .call();
    assert.strictEqual(
      outboundChannelIdentifier,
      outboundChannelIdentifierInContract,
      'Invalid outbound channel identifier.',
    );

    const inboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
      activateParams.metachainId,
      activateParams.erc20Gateway,
      gen0ERC20Cogateway.address,
    );

    const inboundChannelIdentifierInContract = await gen0ERC20Cogateway.inboundChannelIdentifier
      .call();
    assert.strictEqual(
      inboundChannelIdentifier,
      inboundChannelIdentifierInContract,
      'Invalid inbound channel identifier.',
    );
  });
});
