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

const utils = require('../test_lib/utils');
const web3 = require('../test_lib/web3.js');

const MessageInbox = artifacts.require('MessageInbox');
const MessageOutboxDouble = artifacts.require('MessageOutboxDouble');

let messageInbox, messageOutbox;

async function deployMessageOutbox() {
  messageOutbox = await MessageOutboxDouble.new();
  return messageOutbox;
}

async function hashMessage(
  intentHash,
  nonce,
  feeGasPrice,
  feeGasLimit,
  sender,
  channelIdentifier
) {

  const MESSAGE_TYPEHASH = web3.utils.keccak256(
    "Message(bytes32 intentHash,uint256 nonce,uint256 feeGasPrice,uint256 feeGasLimit,address sender)"
  );

  const typedMessageHash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'bytes32',
        'uint256',
        'uint256',
        'uint256',
        'address'
      ],
      [
        MESSAGE_TYPEHASH,
        intentHash,
        nonce.toNumber(),
        feeGasPrice.toNumber(),
        feeGasLimit.toNumber(),
        sender,
      ],
    ),
  );


  const messageHash_ = web3.utils.soliditySha3(
    { t: 'bytes1', v: '0x19' },
    { t: 'bytes1', v: '0x4d' },
    { t: 'bytes32', v: channelIdentifier },
    { t: 'bytes32', v: typedMessageHash },
  );

  return messageHash_;
}

async function hashChannelIdentifier(
  metachainId,
  outbox,
  inbox
) {
  const MMB_CHANNEL_TYPEHASH = web3.utils.keccak256(
    "MosaicMessageBusChannel(address outbox, address inbox)"
  );

  const MMB_DOMAIN_SEPARATOR_TYPEHASH = web3.utils.keccak256(
    "MosaicMessageBus(string name,string version,bytes32 metachainId,bytes32 channelSeparator)"
  );

  const MMB_DOMAIN_SEPARATOR_NAME = "Mosaic-Bus";

  const MMB_DOMAIN_SEPARATOR_VERSION = "0";

  const channelSeparator = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'address',
        'address'
      ],
      [
        MMB_CHANNEL_TYPEHASH,
        outbox,
        inbox
      ],
    ),
  );

  const channelIdentifier = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'string',
        'string',
        'bytes32',
        'bytes32'
      ],
      [
        MMB_DOMAIN_SEPARATOR_TYPEHASH,
        MMB_DOMAIN_SEPARATOR_NAME,
        MMB_DOMAIN_SEPARATOR_VERSION,
        metachainId,
        channelSeparator
      ],
    ),
  );

  return channelIdentifier;
}

module.exports = {
  deployMessageOutbox,
  hashChannelIdentifier,
  hashMessage
}
