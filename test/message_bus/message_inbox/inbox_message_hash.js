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

const ConsensusGatewayUtils = require('../../consensus-gateway/utils.js');
const web3 = require('../../test_lib/web3.js');
const Utils = require('../../test_lib/utils.js');
const { AccountProvider } = require('../../test_lib/utils.js');
const MessageInbox = artifacts.require('MessageInboxDouble');

const BN = require('bn.js');

contract('MessageInbox::inboxMessageHash', (accounts) => {
  let messageInbox;
  const setupParams = {};
  const accountProvider = new AccountProvider(accounts);
  beforeEach(async () => {
    messageInbox = await MessageInbox.new();
    setupParams.intentHash = Utils.getRandomHash();
    setupParams.nonce = new BN(Utils.getRandomNumber(63)); 
    setupParams.feeGasPrice = new BN(Utils.getRandomNumber(9999));
    setupParams.feeGasLimit = new BN(Utils.getRandomNumber(10000));
    setupParams.sender = messageInbox.address;
    setupParams.messageOutbox = await accountProvider.get();
    setupParams.metachainId = Utils.generateRandomMetachainId();
    setupParams.outboxStorageIndex = new BN(Utils.getRandomNumber(63));
    setupParams.stateRoot = await accountProvider.get();
    setupParams.maxStorageRootItems = new BN(Utils.getRandomNumber(500));
  });

  contract('Positive Tests', async () => {
    it('Should successfully generate inbox message hash', async () => {
      await messageInbox.setupMessageInboxExternal(
        setupParams.metachainId,
        setupParams.messageOutbox,
        setupParams.outboxStorageIndex,
        setupParams.stateRoot,
        setupParams.maxStorageRootItems,
      );

      const messageHash = await messageInbox.inboxMessageHash(
        setupParams.intentHash,
        setupParams.nonce,
        setupParams.feeGasPrice,
        setupParams.feeGasLimit,
        setupParams.sender,
      );

      const MESSAGE_TYPEHASH = web3.utils.keccak256(
         'Message(bytes32 intentHash,uint256 nonce,uint256 feeGasPrice,uint256 feeGasLimit,address sender)',
      );

      const expectedinboundChannelIdentifier = ConsensusGatewayUtils.getChannelIdentifier(
        setupParams.metachainId,
        setupParams.messageOutbox,
        messageInbox.address,
      );

      const typedHashed = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          [
            'bytes32',
            'bytes32',
            'uint256',
            'uint256',
            'uint256',
            'address',
          ],
          [
            MESSAGE_TYPEHASH,
            setupParams.intentHash,
            setupParams.nonce.toNumber(),
            setupParams.feeGasPrice.toNumber(),
            setupParams.feeGasLimit.toNumber(),
            setupParams.sender,
          ],
        ),
      );

      const expectedmessageHash = web3.utils.soliditySha3(
        { t: 'bytes1', v: '0x19' },
        { t: 'bytes1', v: '0x4d' },
        { t: 'bytes32', v: expectedinboundChannelIdentifier },
        { t: 'bytes32', v: typedHashed },
      );

      assert.strictEqual(
        messageHash,
        expectedmessageHash,
        'Message Hash from contract should be same as expected hash',
      );
    });
  });
});
