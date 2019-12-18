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

const BN = require('bn.js');

const ConsensusGateway = artifacts.require('ConsensusGateway');

const { AccountProvider } = require('../../test_lib/utils.js');
const Utils = require('../../test_lib/utils.js');
const ConsensusGatewayUtils = require('../utils.js');

contract('ConsensusGateway::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  it('should setup consensus gateway base', async () => {
    const consensusGateway = await ConsensusGateway.new();
    const metachainId = Utils.getRandomHash();
    const most = accountProvider.get();
    const consensusCogateway = accountProvider.get();
    const stateRootProvider = accountProvider.get();
    const maxStorageRootItems = new BN(100);

    await consensusGateway.setup(
      metachainId,
      most,
      consensusCogateway,
      stateRootProvider,
      maxStorageRootItems,
    );

    const mostFromContract = await consensusGateway.most.call();
    const currentMetablockHeightFromContract = await consensusGateway
      .currentMetablockHeight.call();
    const messageInboxFromContract = await consensusGateway.messageInbox.call();
    const outboundMessageIdentifierFromContract = await consensusGateway
      .outboundMessageIdentifier.call();


    const messageOutboxFromContract = await consensusGateway.messageOutbox.call();
    const inboundMessageIdentifierFromContract = await consensusGateway
      .inboundMessageIdentifier.call();

    const inboxOffsetFromContract = await consensusGateway.INBOX_OFFSET.call();
    const outboxOffsetFromContract = await consensusGateway.OUTBOX_OFFSET.call();


    assert.strictEqual(
      most,
      mostFromContract,
      'Most address must match',
    );

    assert.isTrue(
      currentMetablockHeightFromContract.eqn(0),
      `Current metablock height must be 0 but found ${currentMetablockHeightFromContract.toString(10)}`,
    );

    assert.strictEqual(
      messageInboxFromContract,
      consensusCogateway,
      'Inbox contract address must match',
    );

    assert.strictEqual(
      messageOutboxFromContract,
      consensusCogateway,
      'Outbox contract address must match',
    );

    assert.isTrue(
      inboxOffsetFromContract.eqn(4),
      `Inbox offset position must be 4 but found ${inboxOffsetFromContract.toString(10)}`,
    );

    assert.isTrue(
      outboxOffsetFromContract.eqn(1),
      `Outbox offset position must be 1 but found ${outboxOffsetFromContract.toString(10)}`,
    );

    const expectedOutboundMessageIdentifier = ConsensusGatewayUtils.getMessageOutboxIdentifier(
      metachainId,
      consensusGateway.address,
    );
    const expectedInboundMessageIdentifier = ConsensusGatewayUtils.getMessageInboxIdentifier(
      metachainId,
      consensusGateway.address,
    );

    assert.strictEqual(
      expectedInboundMessageIdentifier,
      inboundMessageIdentifierFromContract,
      'Inbound message identifier must match',
    );
    assert.strictEqual(
      expectedOutboundMessageIdentifier,
      outboundMessageIdentifierFromContract,
      'Outbound message identifier must match',
    );
  });
});
