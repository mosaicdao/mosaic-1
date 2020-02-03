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

const { AccountProvider } = require('../../test_lib/utils.js');
const MessageBusUtils = require('../messagebus_utils.js');
const Utils = require('../../test_lib/utils.js');
const web3 = require('../../test_lib/web3.js');

const config = {};

contract('MessageOutbox::declareMessage', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.declareMessageArgs = {
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
      calculatedChannelIdentifier : ''
    };

    config.outbox = await MessageBusUtils.deployMessageOutbox();
    config.declareMessageArgs.calculatedChannelIdentifier =
      await MessageBusUtils.hashChannelIdentifier(
        config.declareMessageArgs.metachainId,
        config.outbox.address,
        config.declareMessageArgs.inboxAddress
      );

    //for initializing outboundChannelIdentifier
    await config.outbox.setupMessageOutboxDouble(
      config.declareMessageArgs.metachainId,
      config.declareMessageArgs.inboxAddress
    );
  });

  contract('Negative Tests', async () => {
    it('should revert if outbox for message hash is already true', async () => {
      await config.outbox.declareMessageDouble(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender
      );

      await Utils.expectRevert(
        config.outbox.declareMessageDouble(
          config.declareMessageArgs.intentHash,
          config.declareMessageArgs.nonce,
          config.declareMessageArgs.feeGasPrice,
          config.declareMessageArgs.feeGasLimit,
          config.declareMessageArgs.sender
        ),
        'Message already exists in the outbox.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should declare a new message', async () => {
      const newMessageHash = await config.outbox.declareMessageDouble.call(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender
      );

      const calculatedMessageHash = await MessageBusUtils.hashMessage(
        config.declareMessageArgs.intentHash,
        config.declareMessageArgs.nonce,
        config.declareMessageArgs.feeGasPrice,
        config.declareMessageArgs.feeGasLimit,
        config.declareMessageArgs.sender,
        config.declareMessageArgs.calculatedChannelIdentifier
      );

      assert.strictEqual(
        calculatedMessageHash,
        newMessageHash
      );
    });
  });
});
