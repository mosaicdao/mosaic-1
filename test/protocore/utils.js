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

const web3 = require('../test_lib/web3.js');

const CheckpointFinalisationStatus = Object.freeze({
  Undefined: 0,
  Registered: 1,
  Justified: 2,
  Finalised: 3,
});

const VOTE_MESSAGE_TYPEHASH = web3.utils.soliditySha3(
  'VoteMessage(bytes32 transitionHash,bytes32 sourceBlockHash,bytes32 targetBlockHash,uint256 sourceBlockNumber,uint256 targetBlockNumber)',
);

function hashVoteMessage(
  domainSeparator,
  sourceTransitionHash,
  sourceBlockHash,
  targetBlockHash,
  sourceBlockNumber,
  targetBlockNumber,
) {
  const voteMessageTypeHash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'bytes32',
        'bytes32',
        'bytes32',
        'uint256',
        'uint256',
      ],
      [
        VOTE_MESSAGE_TYPEHASH,
        sourceTransitionHash,
        sourceBlockHash,
        targetBlockHash,
        sourceBlockNumber.toString(10),
        targetBlockNumber.toString(10),
      ],
    ),
  );
  const voteMessageHash = web3.utils
    .soliditySha3(
      { t: 'bytes', v: '0x19' },
      { t: 'bytes', v: '0x01' },
      { t: 'bytes32', v: domainSeparator },
      { t: 'bytes32', v: voteMessageTypeHash },
    )
    .toString('hex');

  return voteMessageHash;
}

function isUndefined(finalisationStatus) { return finalisationStatus.eqn(0); }

function isRegistered(finalisationStatus) { return finalisationStatus.eqn(1); }

function isJustified(finalisationStatus) { return finalisationStatus.eqn(2); }

function isFinalised(finalisationStatus) { return finalisationStatus.eqn(3); }

module.exports = {
  hashVoteMessage,
  isUndefined,
  isRegistered,
  isJustified,
  isFinalised,
  CheckpointFinalisationStatus,
};
