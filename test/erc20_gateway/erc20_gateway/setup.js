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

'use strict';

const BN = require('bn.js');

const ERC20Gateway = artifacts.require('ERC20Gateway');

const { AccountProvider } = require('../../test_lib/utils.js');
const Utils = require('../../test_lib/utils.js');
const ConsensusGatewayUtils = require('../../consensus-gateway/utils');

const OUTBOX_OFFSET = 1;
const INBOX_OFFSET = 4;

let erc20Gateway;
let metachainId;
let erc20Cogateway;
let stateRootProvider;
let maxStorageRootItems;
let coGatewayOutboxIndex;

contract('ERC20Gateway::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    erc20Gateway = await ERC20Gateway.new();
    metachainId = Utils.getRandomHash();
    erc20Cogateway = accountProvider.get();
    stateRootProvider = accountProvider.get();
    maxStorageRootItems = new BN(50);
    coGatewayOutboxIndex = new BN(1);
  });

  it('should successfully setup ERC20 gateway contract', async () => {
    await erc20Gateway.setup(
      metachainId,
      erc20Cogateway,
      stateRootProvider,
      maxStorageRootItems,
      coGatewayOutboxIndex,
    );

    const messageInboxFromContract = await erc20Gateway.messageInbox.call();
    assert.strictEqual(
      messageInboxFromContract,
      erc20Cogateway,
      'Mismatch in inbox contract address.',
    );

    const messageOutboxFromContract = await erc20Gateway.messageOutbox.call();
    assert.strictEqual(
      messageOutboxFromContract,
      erc20Cogateway,
      'Mismatch in outbox contract address',
    );

    const outboxOffsetFromContract = await erc20Gateway.OUTBOX_OFFSET.call();
    assert.isOk(
      outboxOffsetFromContract.eqn(OUTBOX_OFFSET),
      `Outbox offset position must be ${OUTBOX_OFFSET} but found ${outboxOffsetFromContract.toString(10)}`,
    );

    const inboxOffsetFromContract = await erc20Gateway.INBOX_OFFSET.call();
    assert.isOk(
      inboxOffsetFromContract.eqn(INBOX_OFFSET),
      `Inbox offset position must be ${INBOX_OFFSET} but found ${inboxOffsetFromContract.toString(10)}`,
    );

    const outboundChannelIdentifierFromContract = await erc20Gateway
      .outboundChannelIdentifier.call();
    const expectedOutboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
      metachainId,
      erc20Gateway.address,
      erc20Cogateway,
    );
    assert.strictEqual(
      outboundChannelIdentifierFromContract,
      expectedOutboundChannelIdentifier,
      'Mismatch in outbound channel identifier.',
    );

    const inboundChannelIdentifierFromContract = await erc20Gateway
      .inboundChannelIdentifier.call();
    const expectedInboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
      metachainId,
      erc20Cogateway,
      erc20Gateway.address,
    );

    assert.strictEqual(
      inboundChannelIdentifierFromContract,
      expectedInboundChannelIdentifier,
      'Mismatch in inbound channel identifier.',
    );

    const outboxStorageIndexFromInbox = await erc20Gateway.outboxStorageIndex.call();
    assert.isOk(
      outboxStorageIndexFromInbox.eq(coGatewayOutboxIndex),
      `Expected outbox index is ${coGatewayOutboxIndex.toString(10)} but found ${outboxStorageIndexFromInbox.toString(10)}`,
    );
  });
});
