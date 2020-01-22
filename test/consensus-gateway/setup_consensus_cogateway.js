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

const BN = require('../../node_modules/bn.js/lib/bn');
const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const ConsensusGatewayUtils = require('./utils');

const SpyCoConsensus = artifacts.require('SpyCoConsensus');
const ConsensusCogateway = artifacts.require('ConsensusCogateway');

contract('CoConsensusgateway::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let consensusCogateway;
  const anchor = accountProvider.get();
  const setupParams = {
    metachainId: Utils.getRandomHash(),
    utMOST: accountProvider.get(),
    consensusGateway: accountProvider.get(),
    outboxStorageIndex: new BN(1),
    maxStorageRootItems: new BN(100),
    metablockHeight: new BN(2),
  };

  beforeEach(async () => {
    setupParams.coConsensus = await SpyCoConsensus.new();
    consensusCogateway = await ConsensusCogateway.new();

    await setupParams.coConsensus.setAnchorAddress(setupParams.metachainId, anchor);
  });

  contract('Positive Tests', () => {
    it('should setup successfully', async () => {
      await consensusCogateway.setup(
        setupParams.metachainId,
        setupParams.coConsensus.address,
        setupParams.utMOST,
        setupParams.consensusGateway,
        setupParams.outboxStorageIndex,
        setupParams.maxStorageRootItems,
        setupParams.metablockHeight,
      );

      assert.strictEqual(
        await consensusCogateway.messageInbox.call(),
        setupParams.consensusGateway,
        'Invalid message inbox address',
      );

      assert.strictEqual(
        await setupParams.coConsensus.spyMetachainId.call(),
        setupParams.metachainId,
        'Invalid spy metachain id',
      );

      const fromContractOutBoundChannelIdentifier = await consensusCogateway
        .outboundChannelIdentifier.call();
      const expectedOutBoundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
        setupParams.metachainId,
        consensusCogateway.address,
        setupParams.consensusGateway,
      );
      assert.strictEqual(
        fromContractOutBoundChannelIdentifier,
        expectedOutBoundChannelIdentifier,
        'Invalid outbound channel identifier',
      );

      const outboxStorageIndexInContract = await consensusCogateway.outboxStorageIndex.call();
      assert.strictEqual(
        setupParams.outboxStorageIndex.eq(outboxStorageIndexInContract),
        true,
        `Expected outbox storage index value is ${setupParams.outboxStorageIndex} but got `
        + `${setupParams.outboxStorageIndex}`,
      );

      assert.strictEqual(
        await consensusCogateway.messageOutbox.call(),
        setupParams.consensusGateway,
        'Invalid message outbox address',
      );

      const fromContractInBoundChannelIdentifier = await consensusCogateway
        .inboundChannelIdentifier.call();
      const expectedInBoundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
        setupParams.metachainId,
        setupParams.consensusGateway,
        consensusCogateway.address,
      );
      assert.strictEqual(
        fromContractInBoundChannelIdentifier,
        expectedInBoundChannelIdentifier,
        'Invalid inbound channel identifier',
      );

      const fromContractCurrentMetablockHeight = await consensusCogateway
        .currentMetablockHeight.call();
      assert.strictEqual(
        setupParams.metablockHeight.eq(fromContractCurrentMetablockHeight),
        true,
        `Expected metablock height is ${setupParams.metablockHeight} but`
        + `got ${fromContractCurrentMetablockHeight}`,
      );

      assert.strictEqual(
        setupParams.utMOST,
        await consensusCogateway.most.call(),
        'Invalid most address at auxiliary chain',
      );

      const anchorAddress = await consensusCogateway.stateRootProvider.call();
      assert.strictEqual(
        anchorAddress,
        anchor,
        'Incorrect anchor address',
      );
    });
  });
});
