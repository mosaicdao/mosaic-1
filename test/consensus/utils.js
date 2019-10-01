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

const BN = require('bn.js');
const web3 = require('../test_lib/web3.js');

const COMMITTEE_FORMATION_DELAY = new BN(14);
const COMMITTEE_FORMATION_LENGTH = new BN(7);
const CORE_STATUS_ACTIVE = web3.utils.sha3('CORE_STATUS_ACTIVE').substr(0, 42);
const CORE_STATUS_HALTED = web3.utils.sha3('CORE_STATUS_HALTED').substr(0, 42);
const CORE_STATUS_CORRUPTED = web3.utils.sha3('CORE_STATUS_CORRUPTED').substr(0, 42);
const SENTINEL_COMMITTEES = '0x0000000000000000000000000000000000000001';


module.exports = {
  COMMITTEE_FORMATION_DELAY,
  COMMITTEE_FORMATION_LENGTH,
  CORE_STATUS_ACTIVE,
  CORE_STATUS_HALTED,
  CORE_STATUS_CORRUPTED,
  SENTINEL_COMMITTEES,
};
