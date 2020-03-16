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

const MessageOutboxDouble = artifacts.require('MessageOutboxDouble');
const { AccountProvider } = require('../../test_lib/utils.js');

const MessageBusUtils = require('../messagebus_utils.js');
const Utils = require('../../test_lib/utils.js');

const config = {};

contract('MessageOutbox::declareMessage', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.declareMessageArgs = {
      intentHash: Utils.getRandomHash(),
      nonce: new BN(1),
      feeGasPrice: new BN(5),
      feeGasLimit: new BN(20),
      sender: accountProvider.get(),
    };

    config.metachainId = Utils.getRandomHash();
    config.inboxAddress = accountProvider.get();
    config.calculatedChannelIdentifier = '';

    config.outbox = await MessageOutboxDouble.new();
    config.calculatedChannelIdentifier =
      await MessageBusUtils.hashChannelIdentifier(
        config.metachainId,
        config.outbox.address,
        config.inboxAddress,
      );

    await config.outbox.setupMessageOutboxExternal(
      config.metachainId,
      config.inboxAddress,
    );
  });

  contract('Negative Tests', async () => {
    it('should fail if message hash in outbox is already present', async () => {
      await config.outbox.declareMessageExternal(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender,
      );

      await Utils.expectRevert(
        config.outbox.declareMessageExternal(
          config.declareMessageArgs.intentHash,
          config.declareMessageArgs.nonce,
          config.declareMessageArgs.feeGasPrice,
          config.declareMessageArgs.feeGasLimit,
          config.declareMessageArgs.sender,
        ),
        'Message already exists in the outbox.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should declare a new message', async () => {
      const actualMessageHash = await config.outbox.declareMessageExternal.call(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender,
      );

      const expectedMessageHash = await MessageBusUtils.hashMessage(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender,
        config.calculatedChannelIdentifier,
      );

      assert.strictEqual(
        expectedMessageHash,
        actualMessageHash,
        'Incorrect message hash',
      );

      await config.outbox.declareMessageExternal(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender,
      );

      const outboxMapping = await config.outbox.outbox.call(actualMessageHash);

      assert.ok(
        outboxMapping,
        'message hash in outbox is absent',
      );
    });
  });
});
