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

const { AccountProvider } = require('../../test_lib/utils');
const MessageBusUtils = require('../messagebus_utils');
const Utils = require('../../test_lib/utils');

const config = {};

contract('MessageOutbox::outboxMessageHash', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.OutboxMessageHashArgs = {
      intentHash: Utils.getRandomHash(),
      nonce: new BN(1),
      feeGasPrice: new BN(5),
      feeGasLimit: new BN(20),
      sender: accountProvider.get(),
    };

    config.metachainId = Utils.getRandomHash();
    config.inboxAddress = accountProvider.get();
    config.calculatedChannelIdentifier = '';


    config.outbox = await MessageBusUtils.deployMessageOutbox();
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

  contract('Positive Tests', async () => {
    it('should return a outbox message hash', async () => {
      const actualMessageHash = await config.outbox.outboxMessageHash(
        config.OutboxMessageHashArgs.intentHash,
        config.OutboxMessageHashArgs.nonce,
        config.OutboxMessageHashArgs.feeGasPrice,
        config.OutboxMessageHashArgs.feeGasLimit,
        config.OutboxMessageHashArgs.sender,
      );

      const expectedMessageHash = await MessageBusUtils.hashMessage(
        config.OutboxMessageHashArgs.intentHash,
        config.OutboxMessageHashArgs.nonce,
        config.OutboxMessageHashArgs.feeGasPrice,
        config.OutboxMessageHashArgs.feeGasLimit,
        config.OutboxMessageHashArgs.sender,
        config.calculatedChannelIdentifier,
      );

      assert.strictEqual(
        actualMessageHash,
        expectedMessageHash,
        'Incorrect message hash',
      );
    });
  });
});
