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

const { AccountProvider } = require('../test_lib/utils.js');
const CoreUtils = require('./utils.js');
const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3.js');

const MockCore = artifacts.require('MockCore');

const config = {};

async function hashKernel(
  coreAddress,
  chainId,
  height,
  parent,
  updatedValidators,
  updatedReputation,
  gasTarget,
) {
  const KERNEL_TYPEHASH = web3.utils.keccak256(
    'Kernel(uint256 height,bytes32 parent,address[] updatedValidators,'
    + 'uint256[] updatedReputation,uint256 gasTarget,uint256 gasPrice)',
  );

  const DOMAIN_SEPARATOR_TYPEHASH = web3.utils.keccak256(
    'EIP712Domain(string name,string version,bytes20 chainId,address verifyingContract)',
  );
  const DOMAIN_SEPARATOR_NAME = 'Mosaic-Core';
  const DOMAIN_SEPARATOR_VERSION = '0';

  const domainSeparator = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'string',
        'string',
        'bytes20',
        'address',
      ],
      [
        DOMAIN_SEPARATOR_TYPEHASH,
        DOMAIN_SEPARATOR_NAME,
        DOMAIN_SEPARATOR_VERSION,
        chainId,
        coreAddress,
      ],
    ),
  );

  const typedKernelHash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'uint256',
        'bytes32',
        'address[] memory',
        'uint256[] memory',
        'uint256',
      ],
      [
        KERNEL_TYPEHASH,
        height.toNumber(),
        parent,
        updatedValidators,
        updatedReputation,
        gasTarget.toNumber(),
      ],
    ),
  );

  const hash = web3.utils.soliditySha3(
    { t: 'bytes1', v: '0x19' },
    { t: 'bytes1', v: '0x01' },
    { t: 'bytes32', v: domainSeparator },
    { t: 'bytes32', v: typedKernelHash },
  );

  return hash;
}

/** Proposes a metablock (with specified args) to the given core. */
async function proposeMetablock(
  proposalArgs, core,
) {
  const proposalHash = await core.proposeMetablock.call(
    proposalArgs.kernelHash,
    proposalArgs.originObservation,
    proposalArgs.dynasty,
    proposalArgs.accumulatedGas,
    proposalArgs.committeeLock,
    proposalArgs.source,
    proposalArgs.target,
    proposalArgs.sourceBlockHeight,
    proposalArgs.targetBlockHeight,
  );

  await core.proposeMetablock(
    proposalArgs.kernelHash,
    proposalArgs.originObservation,
    proposalArgs.dynasty,
    proposalArgs.accumulatedGas,
    proposalArgs.committeeLock,
    proposalArgs.source,
    proposalArgs.target,
    proposalArgs.sourceBlockHeight,
    proposalArgs.targetBlockHeight,
  );

  return proposalHash;
}

contract('Core::openMetablock', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.consensusCoreArgs = {
      chainId: accountProvider.get(),
      epochLength: new BN(100),
      minValidatorCount: new BN(5),
      validatorJoinLimit: new BN(20),
      height: new BN(1),
      parent: CoreUtils.randomSha3(),
      gasTarget: new BN(1),
      dynasty: new BN(1),
      accumulatedGas: new BN(1),
      source: accountProvider.get(),
      sourceBlockHeight: new BN(100),
    };

    config.consensus = await CoreUtils.createConsensusCore(
      config.consensusCoreArgs.chainId,
      config.consensusCoreArgs.epochLength,
      config.consensusCoreArgs.minValidatorCount,
      config.consensusCoreArgs.validatorJoinLimit,
      config.consensusCoreArgs.height,
      config.consensusCoreArgs.parent,
      config.consensusCoreArgs.gasTarget,
      config.consensusCoreArgs.dynasty,
      config.consensusCoreArgs.accumulatedGas,
      config.consensusCoreArgs.source,
      config.consensusCoreArgs.sourceBlockHeight,
      { from: accountProvider.get() },
    );

    const coreAddress = await config.consensus.mockCore();
    config.core = await MockCore.at(coreAddress);

    const { validators } = await CoreUtils.openCore(
      config.consensus, config.core,
    );
    config.validators = validators;

    config.proposalArgs = {
      kernelHash: await config.core.openKernelHash(),
      originObservation: CoreUtils.randomSha3(),
      dynasty: new BN(2),
      accumulatedGas: new BN(2),
      committeeLock: CoreUtils.randomSha3(),
      source: CoreUtils.randomSha3(),
      target: CoreUtils.randomSha3(),
      sourceBlockHeight: config.consensusCoreArgs.sourceBlockHeight
        .add(config.consensusCoreArgs.epochLength
          .mul(new BN(2))),
      targetBlockHeight: config.consensusCoreArgs.sourceBlockHeight
        .add(config.consensusCoreArgs.epochLength
          .mul(new BN(3))),
    };
    config.proposalHash = await proposeMetablock(
      config.proposalArgs, config.core,
    );

    config.newMetablockDeltaGasTarget = 1;
  });

  contract('Negative Tests', async () => {
    it('should revert if core has not precommitted', async () => {
      await Utils.expectRevert(
        config.consensus.openMetablock(
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.source,
          config.proposalArgs.sourceBlockHeight,
          config.newMetablockDeltaGasTarget,
        ),
        'The core must be precommitted.',
      );
    });

    it('should revert if caller is not consensus', async () => {
      await CoreUtils.precommitCore(
        config.core,
        config.proposalHash,
        config.validators,
      );

      await Utils.expectRevert(
        config.core.openMetablock(
          config.proposalArgs.dynasty,
          config.proposalArgs.accumulatedGas,
          config.proposalArgs.source,
          config.proposalArgs.sourceBlockHeight,
          config.newMetablockDeltaGasTarget,
        ),
        'Only the consensus contract can call this function.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should open a new metablock', async () => {
      await CoreUtils.precommitCore(
        config.core,
        config.proposalHash,
        config.validators,
      );

      const countValidators = await config.core.countValidators();
      const countJoinMessages = await config.core.countJoinMessages();
      const countLogOutMessages = await config.core.countLogOutMessages();

      const nextKernelHeight = new BN(config.consensusCoreArgs.height).add(new BN(1));
      const updatedValidators = await config.core.updatedValidators(
        nextKernelHeight,
      );
      let updatedReputations = await config.core.updatedReputations(
        nextKernelHeight,
      );
      updatedReputations = updatedReputations.map(
        el => parseInt(el, 10),
      );

      await config.consensus.openMetablock(
        config.proposalArgs.dynasty,
        config.proposalArgs.accumulatedGas,
        config.proposalArgs.source,
        config.proposalArgs.sourceBlockHeight,
        config.newMetablockDeltaGasTarget,
      );

      const committedDynasty = await config.core.committedDynasty();
      assert.isOk(
        committedDynasty.eq(config.proposalArgs.dynasty),
      );

      const committedAccumulatedGas = await config.core.committedAccumulatedGas();
      assert.isOk(
        committedAccumulatedGas.eq(config.proposalArgs.accumulatedGas),
      );

      const committedSource = await config.core.committedSource();
      assert.strictEqual(
        committedSource,
        config.proposalArgs.source,
      );

      const committedSourceBlockHeight = await config.core.committedSourceBlockHeight();
      assert.isOk(
        committedSourceBlockHeight.eq(config.proposalArgs.sourceBlockHeight),
      );

      const openKernelHeight = await config.core.openKernelHeight();
      assert.isOk(
        nextKernelHeight.eq(openKernelHeight),
      );

      const nextKernel = await config.core.kernels(nextKernelHeight);
      assert.strictEqual(
        nextKernel.parent,
        config.proposalHash,
      );
      assert.isOk(
        nextKernel.gasTarget.eq(
          new BN(config.proposalArgs.accumulatedGas).add(
            new BN(config.newMetablockDeltaGasTarget),
          ),
        ),
      );

      const newCountValidators = await config.core.countValidators();
      assert.isOk(
        newCountValidators.eq(
          countValidators.add(countJoinMessages).sub(countLogOutMessages),
        ),
      );

      const newCountJoinMessages = await config.core.countJoinMessages();
      assert.isOk(
        newCountJoinMessages.eqn(0),
      );

      const newCountLogOutMessages = await config.core.countLogOutMessages();
      assert.isOk(
        newCountLogOutMessages.eqn(0),
      );

      const newKernelHash = await config.core.openKernelHash();
      const expectedKernelHash = await hashKernel(
        config.core.address,
        config.consensusCoreArgs.chainId,
        config.consensusCoreArgs.height.add(new BN(1)),
        config.proposalHash,
        updatedValidators,
        updatedReputations,
        new BN(config.proposalArgs.accumulatedGas).add(
          new BN(config.newMetablockDeltaGasTarget),
        ),
      );

      assert.strictEqual(
        newKernelHash,
        expectedKernelHash,
      );

      const actualQuorum = await config.core.quorum();
      const coreSuperMajorityNumerator = await config.core.CORE_SUPER_MAJORITY_NUMERATOR();
      const coreSuperMajorityDenominator = await config.core.CORE_SUPER_MAJORITY_DENOMINATOR();
      const actualValidatorsCount = await config.core.countValidators();

      const expectedQuorum = actualValidatorsCount
        .mul(coreSuperMajorityNumerator)
        .divRound(coreSuperMajorityDenominator);

      assert.isOk(
        actualQuorum.eq(expectedQuorum),
      );

      const isProposalSetInitialized = await config.core.isProposalSetInitialized(
        nextKernelHeight,
      );
      assert.isOk(
        isProposalSetInitialized,
      );
    });
  });
});
