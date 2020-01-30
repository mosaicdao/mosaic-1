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

const BN = require('bn.js');

const TestProtocore = artifacts.require('TestProtocore');

const ProtocoreUtils = require('./utils.js');
const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const config = {};


async function createValidators(
  validatorCount,
) {
  const validators = [];
  for (let i = 0; i < validatorCount; i += 1) {
    const v = await ProtocoreUtils.Validator.create();
    validators.push(v);
  }

  return {
    validators,
  };
}

async function addToFVS(
  protocore,
  validators,
  metablockHeight,
) {
  for (let i = 0; i < validators.length; i += 1) {
    await protocore.addToFVS(validators[i].address, metablockHeight);
  }
}

async function incrementMetablockHeight(
  protocore,
  coconsensusAddress,
) {
  const openKernelHeight = await protocore.openKernelHeight();
  const nextKernelHeight = openKernelHeight.addn(1);

  await config.protocore.openKernel(
    nextKernelHeight,
    Utils.getRandomHash(), // next kernel hash
    { from: coconsensusAddress },
  );
}

contract('Protocore::registerVoteInternal', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.coconsensusAddress = accountProvider.get();
    config.domainSeparator = Utils.getRandomHash();
    config.epochLength = new BN(100);
    config.metachainId = Utils.getRandomHash();

    config.genesisKernelHeight = new BN(1);
    config.genesisKernelHash = Utils.getRandomHash();
    config.genesisParentVoteMessageHash = Utils.getRandomHash();
    config.genesisSourceTransitionHash = Utils.getRandomHash();
    config.genesisSourceBlockHash = Utils.getRandomHash();
    config.genesisTargetBlockHash = Utils.getRandomHash();
    config.genesisSourceBlockNumber = new BN(0);
    config.genesisTargetBlockNumber = new BN(config.epochLength);
    config.genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
      config.domainSeparator,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
    );
    config.genesisProposedMetablockHeight = new BN(1);

    config.protocore = await TestProtocore.new(
      config.coconsensusAddress,
      config.metachainId,
      config.domainSeparator,
      config.epochLength,
      config.genesisKernelHeight,
      config.genesisKernelHash,
      config.genesisParentVoteMessageHash,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
      config.genesisProposedMetablockHeight,
    );
  });

  contract('Negative Tests', async () => {
    it('should fail if a finalisation status of a target checkpoint '
      + 'is less than registered', async () => {
      const v = await ProtocoreUtils.Validator.create();
      const sig = await v.ecsign(Utils.getRandomHash());

      await Utils.expectRevert(
        config.protocore.registerVote(
          Utils.getRandomHash(),
          sig.r, sig.s, sig.v,
        ),
        'The given link status is at least reported.',
      );
    });
    it('should fail if a link height inclusion principle is not kept', async () => {
      const v = await ProtocoreUtils.Validator.create();

      const {
        voteMessageHash,
      } = await ProtocoreUtils.proposeNonFinalisationLinkInternal(
        config.protocore,
        config.genesisVoteMessageHash,
      );

      await incrementMetablockHeight(config.protocore, config.coconsensusAddress);
      await incrementMetablockHeight(config.protocore, config.coconsensusAddress);

      const sig = await v.ecsign(voteMessageHash);

      await Utils.expectRevert(
        config.protocore.registerVote(
          voteMessageHash,
          sig.r, sig.s, sig.v,
        ),
        'Link height inclusion principle has surpassed.',
      );
    });
    it('should fail if a validator has already voted for a height', async () => {
      const openMetablockHeight = await config.protocore.openKernelHeight();
      const nextMetablockHeight = openMetablockHeight.addn(1);

      const v = await ProtocoreUtils.Validator.create();
      await addToFVS(config.protocore, [v], nextMetablockHeight);

      await incrementMetablockHeight(config.protocore, config.coconsensusAddress);

      const {
        voteMessageHash,
      } = await ProtocoreUtils.proposeNonFinalisationLinkInternal(
        config.protocore,
        config.genesisVoteMessageHash,
      );

      const sig = await v.ecsign(voteMessageHash);

      await config.protocore.registerVote(
        voteMessageHash,
        sig.r, sig.s, sig.v,
      );

      await Utils.expectRevert(
        config.protocore.registerVote(
          voteMessageHash,
          sig.r, sig.s, sig.v,
        ),
        'Validator vote cannot be registered twice in FVS votes at the same height.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks that a vote of a validator is not double-counting', async () => {
    });
    it('checks that if a quorum reached link is justified', async () => {
    });
    it('checks that if a quorum reached a finalisation link is marked as finalised '
      + 'and coconsensus is notified', async () => {
    });
  });
});
