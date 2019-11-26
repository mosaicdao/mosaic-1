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

const BN = require('bn.js');
const EthUtils = require('ethereumjs-util');

const web3 = require('../test_lib/web3.js');

const Core = artifacts.require('Core');
const MockConsensus = artifacts.require('MockConsensus');

const CoreStatus = {
  creation: new BN(0),
  opened: new BN(1),
  precommitted: new BN(2),
  halted: new BN(3),
  corrupted: new BN(4),
};


function isCoreCreated(status) {
  return CoreStatus.creation.cmp(status) === 0;
}

function isCoreOpened(status) {
  return CoreStatus.opened.cmp(status) === 0;
}

function isCorePrecommitted(status) {
  return CoreStatus.precommitted.cmp(status) === 0;
}

function isCoreHalted(status) {
  return CoreStatus.halted.cmp(status) === 0;
}

function isCoreCorrupted(status) {
  return CoreStatus.corrupted.cmp(status) === 0;
}

async function createValidator() {
  const account = await web3.eth.accounts.create();
  return {
    address: account.address,
    privateKey: account.privateKey,
  };
}

async function createConsensusCore(
  chainId,
  epochLength,
  minValidatorCount,
  validatorJoinLimit,
  height,
  parent,
  gasTarget,
  dynasty,
  accumulatedGas,
  source,
  sourceBlockHeight,
  txOptions = {},
) {
  const mockConsensus = await MockConsensus.new(
    chainId,
    epochLength,
    minValidatorCount,
    validatorJoinLimit,
    height,
    parent,
    gasTarget,
    dynasty,
    accumulatedGas,
    source,
    sourceBlockHeight,
    txOptions,
  );

  return mockConsensus;
}

async function createCore(
  chainId,
  epochLength,
  minValidators,
  joinLimit,
  reputation,
  height,
  parent,
  gasTarget,
  dynasty,
  accumulatedGas,
  source,
  sourceBlockHeight,
  txOptions = {},
) {
  return Core.new(
    chainId,
    epochLength,
    minValidators,
    joinLimit,
    reputation,
    height,
    parent,
    gasTarget,
    dynasty,
    accumulatedGas,
    source,
    sourceBlockHeight,
    txOptions,
  );
}

async function openCore(
  consensus,
  core,
) {
  const minVal = await core.minimumValidatorCount.call();

  const validators = [];
  for (let i = 0; i < minVal.toNumber(10); i += 1) {
    // eslint-disable-next-line no-await-in-loop
    const validator = await createValidator();
    // eslint-disable-next-line no-await-in-loop
    await consensus.joinDuringCreation(validator.address);
    validators.push(validator);
  }

  const coreStatus = await core.coreStatus.call();
  assert.isOk(
    isCoreOpened(coreStatus),
  );

  return {
    validators,
  };
}

async function signProposal(proposalHash, privateKey) {
  const proposalSignature = EthUtils.ecsign(
    EthUtils.toBuffer(proposalHash),
    EthUtils.toBuffer(privateKey),
  );

  return {
    r: EthUtils.bufferToHex(proposalSignature.r),
    s: EthUtils.bufferToHex(proposalSignature.s),
    v: web3.utils.toDecimal(proposalSignature.v),
  };
}

async function precommitCore(
  core,
  proposalHash,
  validators,
) {
  const quorum = await core.quorum();

  assert(quorum > 0);
  assert(quorum <= validators.length);

  for (let i = 0; i < quorum; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    const signature = await signProposal(
      proposalHash, validators[i].privateKey,
    );

    // eslint-disable-next-line no-await-in-loop
    await core.registerVote(
      proposalHash, signature.r, signature.s, signature.v,
    );
  }

  const precommit = await core.precommit();
  assert.strictEqual(
    precommit,
    proposalHash,
  );

  const coreStatus = await core.coreStatus();
  assert.isOk(
    isCorePrecommitted(coreStatus),
  );
}

async function calculateQuorum(core, count) {
  const numerator = await core.CORE_SUPER_MAJORITY_NUMERATOR.call();
  const denumerator = await core.CORE_SUPER_MAJORITY_DENOMINATOR.call();

  return count
    .mul(numerator)
    .div(denumerator);
}

function randomSha3() {
  const randomString = Math.random().toString(36).substring(2, 15);
  return web3.utils.sha3(randomString);
}

module.exports = {
  createConsensusCore,
  createCore,
  createValidator,
  signProposal,
  openCore,
  precommitCore,
  isCoreCreated,
  isCoreOpened,
  isCorePrecommitted,
  isCoreHalted,
  isCoreCorrupted,
  calculateQuorum,
  randomSha3,
};
