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

const { AccountProvider } = require('../../test_lib/utils.js');
const MessageBusUtils = require('../messagebus_utils.js');
const Utils = require('../../test_lib/utils.js');

const config = {};

contract('MessageOutbox::setupMessageOutbox', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.SetupMessageOutboxArgs = {
      metachainId: Utils.getRandomHash(),
      inboxAddress: accountProvider.get(),
    };

    config.outboxAddress = await MessageBusUtils.deployMessageOutbox();

  });

  contract('Negative Tests', async () => {
    it('should fail if message outbox is already setup', async () => {
      await config.outboxAddress.setupMessageOutboxDouble(
        config.SetupMessageOutboxArgs.metachainId,
        config.SetupMessageOutboxArgs.inboxAddress,
      );

      await Utils.expectRevert(
        config.outboxAddress.setupMessageOutboxDouble(
          config.SetupMessageOutboxArgs.metachainId,
          config.SetupMessageOutboxArgs.inboxAddress,
        ),
        'Message outbox is already setup.',
      );
    });

    it('should fail if metachainId is 0', async () => {
      await Utils.expectRevert(
        config.outboxAddress.setupMessageOutboxDouble(
          Utils.ZERO_BYTES32,
          config.SetupMessageOutboxArgs.inboxAddress,
        ),
        'Metachain id is 0.',
      );
    });

    it('should fail if message inbox address is 0', async () => {
      await Utils.expectRevert(
        config.outboxAddress.setupMessageOutboxDouble(
          config.SetupMessageOutboxArgs.metachainId,
          Utils.NULL_ADDRESS,
        ),
        'Message inbox address is 0.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should successfully setup message outbox', async () => {
      await config.outboxAddress.setupMessageOutboxDouble(
        config.SetupMessageOutboxArgs.metachainId,
        config.SetupMessageOutboxArgs.inboxAddress,
      );

      const expectedChannelIdentifier = await MessageBusUtils.hashChannelIdentifier(
        config.SetupMessageOutboxArgs.metachainId,
        config.outboxAddress.address,
        config.SetupMessageOutboxArgs.inboxAddress,
      );

      assert.strictEqual(
        await config.outboxAddress.outboundChannelIdentifier(),
        expectedChannelIdentifier,
        'Invalid channel identifier',
      );

      assert.strictEqual(
        await config.outboxAddress.messageInbox(),
        config.SetupMessageOutboxArgs.inboxAddress,
        'Invalid message inbox address',
      );
    });
  });
});
