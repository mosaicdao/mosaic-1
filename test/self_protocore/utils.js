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

const web3 = require('../test_lib/web3.js');

const SOURCE_TRANSITION_TYPEHASH = web3.utils.soliditySha3('Source(bytes32 kernelHash,bytes32 originObservation,uint256 dynasty,uint256 accumulatedGas,bytes32 committeeLock)');

function hashSourceTransition(
  domainSeparator,
  sourceKernelHash,
  sourceOriginObservation,
  sourceDynasty,
  sourceAccumulatedGas,
  sourceCommitteeLock,
) {
  const sourceTransitionTypeHash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      ['bytes32', 'bytes32', 'bytes32', 'uint256', 'uint256', 'bytes32'],
      [
        SOURCE_TRANSITION_TYPEHASH,
        sourceKernelHash,
        sourceOriginObservation,
        sourceDynasty.toString(10),
        sourceAccumulatedGas.toString(10),
        sourceCommitteeLock,
      ],
    ),
  );

  const sourceTransitionHash = web3.utils
    .soliditySha3(
      { t: 'bytes', v: '0x19' },
      { t: 'bytes', v: '0x01' },
      { t: 'bytes32', v: domainSeparator },
      { t: 'bytes32', v: sourceTransitionTypeHash },
    )
    .toString('hex');

  return sourceTransitionHash;
}

module.exports = {
  hashSourceTransition,
};
