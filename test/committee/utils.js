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

const Committee = artifacts.require('Committee');

function remove0x(str) {
  if (str.substr(0, 2) === '0x') {
    return str.substr(2);
  }

  return str;
}

async function createCommittee(committeeSize, dislocation, proposal) {
  return Committee.new(
    committeeSize,
    dislocation,
    proposal,
  );
}

function shuffleAccount(dislocation, account) {
  return web3.utils.soliditySha3(
    { t: 'address', v: account },
    { t: 'bytes32', v: dislocation },
  );
}

function distance(h1, h2) {
  // Create BN from hashes.
  const a = new BN(remove0x(h1), 16);
  const b = new BN(remove0x(h2), 16);

  // Return XOR as big number.
  return a.xor(b);
}

function distanceToProposal(dislocation, account, proposal) {
  return distance(shuffleAccount(dislocation, account), proposal);
}

const CommitteeStatus = {
  Open: new BN(0),
  Cooldown: new BN(1),
  CommitPhase: new BN(2),
  RevealPhase: new BN(3),
  Closed: new BN(4),
  Invalid: new BN(5),
};

function isCommitteeOpen(status) {
  return CommitteeStatus.Open.cmp(status) === 0;
}

const SENTINEL_MEMBERS = '0x1';

module.exports = {
  createCommittee,
  distance,
  shuffleAccount,
  distanceToProposal,
  CommitteeStatus,
  isCommitteeOpen,
  SENTINEL_MEMBERS,
};
