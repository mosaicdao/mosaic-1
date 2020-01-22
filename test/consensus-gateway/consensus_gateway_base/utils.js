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

const web3 = require('../../test_lib/web3.js');

const DEPOSIT_INTENT_TYPEHASH = web3.utils.soliditySha3('DepositIntent(uint256 amount,address beneficiary)');

function getDepositIntentHash(amount, beneficiary) {
  return web3.utils.sha3(
    web3.eth.abi.encodeParameters(
      ['bytes32', 'uint256', 'address'],
      [DEPOSIT_INTENT_TYPEHASH, amount.toString(), beneficiary],
    ),
  );
}

module.exports = {
  DEPOSIT_INTENT_TYPEHASH,
  getDepositIntentHash,
};
