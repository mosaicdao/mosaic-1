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
const MockConsensus = artifacts.require('MockConsensus');

const { AccountProvider } = require('../../test_lib/utils.js');
const Utils = require('../../test_lib/utils.js');
const ConsensusGatewayUtils = require('../utils.js');
const { CONSENSUS_GATEWAY_INBOX_OFFSET, CONSENSUS_GATEWAY_OUTBOX_OFFSET } = require('../utils');

contract('ConsensusGateway::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  it('should setup consensus gateway', async () => {
    const consensusGateway = await ConsensusGateway.new();
    const metachainId = Utils.getRandomHash();
    const most = accountProvider.get();
    const consensusCogateway = accountProvider.get();
    const maxStorageRootItems = new BN(100);
    const coGatewayOutboxIndex = new BN(1);

    const consensusConfig = {
      metachainId,
      epochLength: new BN(100),
      minValidatorCount: new BN(5),
      validatorJoinLimit: new BN(20),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(10),
      dynasty: new BN(0),
      accumulatedGas: new BN(1),
      sourceBlockHeight: new BN(0),
    };

    const consensus = await MockConsensus.new(
      consensusConfig.metachainId,
      consensusConfig.epochLength,
      consensusConfig.minValidatorCount,
      consensusConfig.validatorJoinLimit,
      consensusConfig.height,
      consensusConfig.parent,
      consensusConfig.gasTarget,
      consensusConfig.dynasty,
      consensusConfig.accumulatedGas,
      consensusConfig.sourceBlockHeight,
    );
    await consensusGateway.setup(
      metachainId,
      consensus.address,
      most,
      consensusCogateway,
      maxStorageRootItems,
      coGatewayOutboxIndex,
    );

    const mostFromContract = await consensusGateway.most.call();
    const currentMetablockHeightFromContract = await consensusGateway
      .currentMetablockHeight.call();
    const messageInboxFromContract = await consensusGateway.messageInbox.call();
    const outboundChannelIdentifierFromContract = await consensusGateway
      .outboundChannelIdentifier.call();


    const messageOutboxFromContract = await consensusGateway.messageOutbox.call();
    const inboundChannelIdentifierFromContract = await consensusGateway
      .inboundChannelIdentifier.call();

    const inboxOffsetFromContract = await consensusGateway.INBOX_OFFSET.call();
    const outboxOffsetFromContract = await consensusGateway.OUTBOX_OFFSET.call();


    assert.strictEqual(
      most,
      mostFromContract,
      'MOST address must match',
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
      inboxOffsetFromContract.eqn(CONSENSUS_GATEWAY_INBOX_OFFSET),
      `Inbox offset position must be 4 but found ${inboxOffsetFromContract.toString(10)}`,
    );

    assert.isTrue(
      outboxOffsetFromContract.eqn(CONSENSUS_GATEWAY_OUTBOX_OFFSET),
      `Outbox offset position must be 1 but found ${outboxOffsetFromContract.toString(10)}`,
    );

    const expectedOutboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
      metachainId,
      consensusGateway.address,
      consensusCogateway,
    );
    assert.strictEqual(
      expectedOutboundChannelIdentifier,
      outboundChannelIdentifierFromContract,
      'Outbound message identifier must match',
    );

    const expectedInboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
      metachainId,
      consensusCogateway,
      consensusGateway.address,
    );
    assert.strictEqual(
      expectedInboundChannelIdentifier,
      inboundChannelIdentifierFromContract,
      'Inbound message identifier must match',
    );

    const outboxStorageIndexFromInbox = await consensusGateway.outboxStorageIndex.call();
    assert.isOk(
      outboxStorageIndexFromInbox.eq(coGatewayOutboxIndex),
      `Expected outbox index is ${coGatewayOutboxIndex.toString(10)} but found ${outboxStorageIndexFromInbox.toString(10)}`,
    );

    const consensusAddressFromContract = await consensusGateway.consensus.call();

    assert.strictEqual(
      consensus.address,
      consensusAddressFromContract,
      'Consensus address must match',
    );
  });
});
