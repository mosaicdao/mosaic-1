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

async function createCommittee(committeeSize, dislocation, proposal) {
  const committee = await Committee.new(
    committeeSize,
    dislocation,
    proposal,
  );

  return committee;
}

function distanceToProposal(dislocation, account, proposal) {
  return distance(shuffleAccount(dislocation, account), proposal);
}

function shuffleAccount(dislocation, account) {
  return web3.utils.soliditySha3(
    { t: 'address', v: account },
    { t: 'bytes32', v: dislocation },
  );
}

function distance(h1, h2) {
  // create BN from hashes
  var a = new BN(h1, 16);
  var b = new BN(h2, 16);
  // return XOR as big number
  return a.xor(b);
}

module.exports = {

  createCommittee,

  shuffleAccount,

  distance,

  distanceToProposal,
};