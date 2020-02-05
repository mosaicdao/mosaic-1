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

const BN = require('bn.js');
const web3 = require('../../test_lib/web3.js');
const Utils = require('../../test_lib/utils.js');
const { AccountProvider } = require('../../test_lib/utils.js');

const MessageInbox = artifacts.require('MessageInboxDouble');

contract('MessageInbox::setupMessageInbox', (accounts) => {
  let messageInbox;
  const setupParams = {};
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    setupParams.metachainId = Utils.generateRandomMetachainId();
    setupParams.messageOutbox = await accountProvider.get();
    setupParams.outboxStorageIndex = new BN(Utils.getRandomNumber(63));// need to verify thr range
    setupParams.stateRootI = await accountProvider.get();
    setupParams.maxStorageRootItems = new BN(Utils.getRandomNumber(500));
    setupParams.txOptions = {
      from: accountProvider.get(),
    };
    messageInbox = await MessageInbox.new();
  });

  contract('Positive Tests', async () => {
    it('Should set the parameters', async () => {
      await messageInbox.setupMessageInboxDouble(
        setupParams.metachainId,
        setupParams.messageOutbox,
        setupParams.outboxStorageIndex,
        setupParams.stateRootI,
        setupParams.maxStorageRootItems,
      );

      const messageOutbox = await messageInbox.messageOutbox.call();

      assert.strictEqual(
        messageOutbox,
        setupParams.messageOutbox,
        'Message Outbox  from contract must be same as setupParams.messageOutbox',
      );

      const outboxStorageIndex = await messageInbox.outboxStorageIndex.call();

      assert.strictEqual(
        setupParams.outboxStorageIndex.eq(outboxStorageIndex),
        true,
        'Outbox Storage Index from contract must be same as Outbox Storage Index',
      );

      const MMB_CHANNEL_TYPEHASH = web3.utils.keccak256(
        'MosaicMessageBusChannel(address outbox, address inbox)',
      );

      const MMB_DOMAIN_SEPARATOR_TYPEHASH = web3.utils.keccak256(
        'MosaicMessageBus(string name,string version,bytes32 metachainId,bytes32 channelSeparator)',
      );

      const MMB_DOMAIN_SEPARATOR_NAME = 'Mosaic-Bus';
      const MMB_DOMAIN_SEPARATOR_VERSION = '0';

      const channelSeparator = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          [
            'bytes32',
            'address',
            'address',
          ],
          [
            MMB_CHANNEL_TYPEHASH,
            setupParams.messageOutbox,
            messageInbox.address,
          ],
        ),
      );

      const expectedinboundChannelIdentifier = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          [
            'bytes32',
            'string',
            'string',
            'bytes32',
            'bytes32',
          ],
          [
            MMB_DOMAIN_SEPARATOR_TYPEHASH,
            MMB_DOMAIN_SEPARATOR_NAME,
            MMB_DOMAIN_SEPARATOR_VERSION,
            setupParams.metachainId,
            channelSeparator,
          ],
        ),
      );

      const inboundChannelidentifier = await messageInbox.inboundChannelIdentifier.call();

      assert.strictEqual(
        expectedinboundChannelIdentifier,
        inboundChannelidentifier,
        'Inbound Channel Identifier from contract must be same as expected inbound channel identifier',
      );
    });
  });
});