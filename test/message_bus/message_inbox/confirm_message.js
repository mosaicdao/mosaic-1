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

const ConfirmMessageIntentHash = require('../../data/confirm_message.json');
const web3 = require('../../test_lib/web3.js');
const Utils = require('../../test_lib/utils.js');
const { AccountProvider } = require('../../test_lib/utils.js');
const ConsensusGatewayBase = artifacts.require('ConsensusGatewayBase');
const MessageInbox = artifacts.require('MessageInboxDouble');

const BN = require('bn.js');

contract('MessageInbox::confirmMessage', (accounts) => {
  let messageInbox;
  let consensusGatewayBase;
  const setupParams = {};
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    setupParams.metachainId = ConfirmMessageIntentHash.metachainId;
    setupParams.messageOutbox = await accountProvider.get();
    setupParams.stateRoot = await accountProvider.get();
    setupParams.maxStorageRootItems = new BN(Utils.getRandomNumber(500));
    setupParams.txOptions = {
      from: accountProvider.get(),
    };
    setupParams.nonce = new BN(ConfirmMessageIntentHash.nonce);
    setupParams.feeGasPrice = new BN(10);
    setupParams.feeGasLimit = new BN(10);
    setupParams.sender = ConfirmMessageIntentHash.sender;
    setupParams.blockHeight = ConfirmMessageIntentHash.blockNumber;
    setupParams.kernelHeight = new BN(3);
    setupParams.rlpParentNodes = ConfirmMessageIntentHash.serializedStorageProof;
    setupParams.kernelHash = ConfirmMessageIntentHash.kernelHash;
    messageInbox = await MessageInbox.new();
    consensusGatewayBase = await ConsensusGatewayBase.new();

    setupParams.intentHash = await consensusGatewayBase.hashKernelIntent(
      setupParams.kernelHeight,
      setupParams.kernelHash,
    );

    await messageInbox.setStorageRoots(
      setupParams.blockHeight,
      ConfirmMessageIntentHash.storageHash,
    );

    await messageInbox.setInboundChannelIdentifier(
      ConfirmMessageIntentHash.outboundChannelIdentifier,
    );

    await messageInbox.setOutboxStorageIndex(
      new BN(1),
    );
  });

  contract('Negative Tests', async () => {
    it('Should fail when message hash already exists in inbox mapping', async () => {
      await messageInbox.confirmMessageExternal(
        setupParams.intentHash,
        setupParams.nonce,
        setupParams.feeGasPrice,
        setupParams.feeGasLimit,
        setupParams.sender,
        setupParams.blockHeight,
        setupParams.rlpParentNodes,
      );

      await Utils.expectRevert(
        messageInbox.confirmMessageExternal(
          setupParams.intentHash,
          setupParams.nonce,
          setupParams.feeGasPrice,
          setupParams.feeGasLimit,
          setupParams.sender,
          setupParams.blockHeight,
          setupParams.rlpParentNodes,
        ),
        'Message already exists in the inbox.',
      );
    });
  });
  contract('Positive Tests', async () => {
    it('Should be able to set parameters', async () => {
      const messageHash = await messageInbox.confirmMessageExternal.call(
        setupParams.intentHash,
        setupParams.nonce,
        setupParams.feeGasPrice,
        setupParams.feeGasLimit,
        setupParams.sender,
        setupParams.blockHeight,
        setupParams.rlpParentNodes,
      );

      const inboundChannelIdentifier = await messageInbox.inboundChannelIdentifier();

      const MESSAGE_TYPEHASH = web3.utils.keccak256(
        'Message(bytes32 intentHash,uint256 nonce,uint256 feeGasPrice,uint256 feeGasLimit,address sender)',
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

      const expectedMessageHash = web3.utils.soliditySha3(
        { t: 'bytes1', v: '0x19' },
        { t: 'bytes1', v: '0x4d' },
        { t: 'bytes32', v: inboundChannelIdentifier },
        { t: 'bytes32', v: typedHashed },
      );

      assert.strictEqual(
        messageHash,
        expectedMessageHash,
        'Message Hash from contract should be same as expected hash',
      );

      await messageInbox.confirmMessageExternal(
        setupParams.intentHash,
        setupParams.nonce,
        setupParams.feeGasPrice,
        setupParams.feeGasLimit,
        setupParams.sender,
        setupParams.blockHeight,
        setupParams.rlpParentNodes,
      );

      const inboxMapping = await messageInbox.inbox.call(messageHash);

      assert.ok(
        inboxMapping,
        'Message Hash is not present in the mapping',
      );
    });
  });
});
