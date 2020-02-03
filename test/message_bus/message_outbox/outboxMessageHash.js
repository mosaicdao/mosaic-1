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
const web3 = require('../../test_lib/web3');

const config = {};

contract('MessageOutbox::outboxMessageHash', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.OutboxMessageHashArgs = {
      intentHash: web3.utils.soliditySha3({
        type: 'bytes32',
        value: 'intent',
      }),
      nonce: new BN(1),
      feeGasPrice: new BN(5),
      feeGasLimit: new BN(20),
      sender: accountProvider.get(),
      metachainId: Utils.getRandomHash(),
      inboxAddress: accountProvider.get(),
      calculatedChannelIdentifier: ''
    };


    config.outbox = await MessageBusUtils.deployMessageOutbox();
    config.OutboxMessageHashArgs.calculatedChannelIdentifier =
      await MessageBusUtils.hashChannelIdentifier(
        config.OutboxMessageHashArgs.metachainId,
        config.outbox.address,
        config.OutboxMessageHashArgs.inboxAddress
      );
    console.log('wwwwwwwwww', config.OutboxMessageHashArgs.calculatedChannelIdentifier)

    await config.outbox.setupMessageOutboxDouble(
      config.OutboxMessageHashArgs.metachainId,
      config.OutboxMessageHashArgs.inboxAddress
    )

    console.log('wwwwwwwwww', await config.outbox.outboundChannelIdentifier())
  });

  contract('Positive Tests', async () => {
    it('should return a outbox message hash', async () => {
      const newMessageHash = await config.outbox.outboxMessageHash(
        config.OutboxMessageHashArgs.intentHash,
        config.OutboxMessageHashArgs.nonce,
        config.OutboxMessageHashArgs.feeGasPrice,
        config.OutboxMessageHashArgs.feeGasLimit,
        config.OutboxMessageHashArgs.sender
      );

      console.log('ssssssssssssss')
      console.log(newMessageHash)

      const expectedMessageHash = await MessageBusUtils.hashMessage(
        config.OutboxMessageHashArgs.intentHash,
        config.OutboxMessageHashArgs.nonce,
        config.OutboxMessageHashArgs.feeGasPrice,
        config.OutboxMessageHashArgs.feeGasLimit,
        config.OutboxMessageHashArgs.sender,
        config.OutboxMessageHashArgs.calculatedChannelIdentifier
      );

      console.log('xxxxxxxxxxxxxx')
      console.log(expectedMessageHash)


          assert.strictEqual(
            newMessageHash,
            expectedMessageHash
          );
    });
  });
});
