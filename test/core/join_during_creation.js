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
const CoreStatusUtils = require('../test_lib/core_status_utils');
const CoreUtils = require('./utils.js');
const Utils = require('../test_lib/utils.js');

const MockCore = artifacts.require('MockCore');

let config = {};

async function assertValidatorHeight(
  core,
  validator,
  expectedBeginHeight,
  expectedEndHeight,
) {
  const beginHeight = await core.validatorBeginHeight(validator);
  const endHeight = await core.validatorEndHeight(validator);

  assert.isOk(
    beginHeight.eq(expectedBeginHeight),
  );

  assert.isOk(
    endHeight.eq(expectedEndHeight),
  );
}

async function assertConfigInCreation(core) {
  const coreStatus0 = await core.coreStatus.call();
  assert.isOk(
    CoreStatusUtils.isCoreCreated(coreStatus0),
  );
}

contract('Core::joinDuringCreation', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      chainId: accountProvider.get(),
      epochLength: new BN(100),
      minValidatorCount: new BN(5),
      validatorJoinLimit: new BN(20),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(10),
      dynasty: new BN(0),
      accumulatedGas: new BN(1),
      source: CoreUtils.randomSha3(),
      sourceBlockHeight: new BN(0),
      deployer: accountProvider.get(),
    };

    config.mockConsensus = await CoreUtils.createConsensusCore(
      config.chainId,
      config.epochLength,
      config.minValidatorCount,
      config.validatorJoinLimit,
      config.height,
      config.parent,
      config.gasTarget,
      config.dynasty,
      config.accumulatedGas,
      config.sourceBlockHeight,
      {
        from: config.deployer,
      },
    );

    const coreAddress = await config.mockConsensus.mockCore.call();

    config.mockCore = await MockCore.at(coreAddress);

    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should fail if a caller is not consensus', async () => {
      assertConfigInCreation(config.mockCore);
      await Utils.expectRevert(
        config.mockCore.joinDuringCreation(
          accountProvider.get(),
          {
            from: accountProvider.get(), // not a consensus
          },
        ),
        'Only the consensus contract can call this function.',
      );
    });

    it('should fail if validator\'s address is null', async () => {
      assertConfigInCreation(config.mockCore);
      await Utils.expectRevert(
        config.mockConsensus.joinDuringCreation(
          Utils.NULL_ADDRESS,
        ),
        'Validator must not be null address.',
      );
    });

    it('should fail if a validator is already part of core', async () => {
      assertConfigInCreation(config.mockCore);

      const validator = accountProvider.get();

      await config.mockConsensus.joinDuringCreation(
        validator,
      );

      await Utils.expectRevert(
        config.mockConsensus.joinDuringCreation(
          validator,
        ),
        'Validator must not already be part of this core.',
      );
    });

    it('should fail if core is not in creation state', async () => {
      assertConfigInCreation(config.mockCore);

      await CoreUtils.openCore(
        config.mockConsensus,
        config.mockCore,
      );

      await Utils.expectRevert(
        config.mockConsensus.joinDuringCreation(
          accountProvider.get(),
        ),
        'The core must be under creation.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should add one validator', async () => {
      assertConfigInCreation(config.mockCore);

      const validator = accountProvider.get();
      const maxFutureEndHeight = await config.mockCore.MAX_FUTURE_END_HEIGHT.call();

      await config.mockConsensus.joinDuringCreation(validator);

      await assertValidatorHeight(
        config.mockCore,
        validator,
        config.height,
        maxFutureEndHeight,
      );

      assertConfigInCreation(config.mockCore);

      const updatedValidatorsCount = await config.mockCore.updatedValidatorsCount(
        config.height,
      );
      assert.isOk(
        updatedValidatorsCount.cmp(new BN(1)) === 0,
        'Updated validators count should be equal to 1.',
      );

      const updatedValidator0 = await config.mockCore.updatedValidator(
        config.height,
        0,
      );
      assert.strictEqual(
        updatedValidator0,
        validator,
        `Updated validator address at index 0 (${updatedValidator0}) `
        + `should match with ${validator}`,
      );

      const updatedReputationCount = await config.mockCore.updatedReputationCount(
        config.height,
      );
      assert.isOk(
        updatedReputationCount.cmp(new BN(1)) === 0,
        'Updated reputation count should be equal to 1.',
      );

      const updatedReputation0 = await config.mockCore.updatedReputation(
        config.height,
        0,
      );
      assert.isOk(
        updatedReputation0.cmp(new BN(1)) === 0,
        `Updated reputation at index 0 (${updatedReputation0}) `
        + 'should be 1.',
      );

      const valCount = await config.mockCore.countValidators.call();
      assert.isOk(
        valCount.eqn(1),
      );
    });

    it('should open after enough validators join', async () => {
      const minVal = await config.mockCore.minimumValidatorCount.call();

      const expectedUpdatedValidators = [];
      const expectedUpdatedReputations = [];
      for (let i = 0; i < minVal.toNumber(10) - 1; i += 1) {
        const validator = accountProvider.get();
        expectedUpdatedValidators.push(validator);
        expectedUpdatedReputations.push(new BN(1));
        // eslint-disable-next-line no-await-in-loop
        await config.mockConsensus.joinDuringCreation(validator);

        // eslint-disable-next-line no-await-in-loop
        const valCount = await config.mockCore.countValidators.call();
        assert.isOk(
          valCount.eqn(i + 1),
        );

        // eslint-disable-next-line no-await-in-loop
        const coreStatus = await config.mockCore.coreStatus.call();
        assert.isOk(
          CoreStatusUtils.isCoreCreated(coreStatus),
        );
      }

      const validator = accountProvider.get();
      expectedUpdatedValidators.push(validator);
      expectedUpdatedReputations.push(new BN(1));
      await config.mockConsensus.joinDuringCreation(validator);
      const valCount = await config.mockCore.countValidators.call();
      assert.isOk(
        valCount.eq(minVal),
      );
      const coreStatus = await config.mockCore.coreStatus.call();
      assert.isOk(
        CoreStatusUtils.isCoreOpened(coreStatus),
      );

      const quorum = await config.mockCore.quorum.call();
      const calcQuorum = await CoreUtils.calculateQuorum(config.mockCore, minVal);
      assert.isOk(
        quorum.eq(calcQuorum),
      );

      const coreOpenVotesWindow = await config.mockCore.CORE_OPEN_VOTES_WINDOW();
      const precommitClosureBlockHeight = await config.mockCore.precommitClosureBlockHeight();
      assert.isOk(
        precommitClosureBlockHeight.cmp(coreOpenVotesWindow) === 0,
        `Precommit closure height (${precommitClosureBlockHeight}) should be equal to `
        + `${coreOpenVotesWindow} on core open.`,
      );

      const openKernelHeight = await config.mockCore.openKernelHeight();
      assert.isOk(
        openKernelHeight.cmp(config.height) === 0,
        `Open kernel height (${openKernelHeight}) should be equal to `
        + `creation kernel height (${config.height})`,
      );

      const openKernelHash = await config.mockCore.openKernelHash();
      const expectedOpenKernelHash = await config.mockCore.externalHashKernel(
        config.height,
        config.parent,
        expectedUpdatedValidators,
        expectedUpdatedReputations,
        config.gasTarget,
      );
      assert.strictEqual(
        openKernelHash,
        expectedOpenKernelHash,
      );

      const isProposalSetInitialized = await config.mockCore.isProposalSetInitialized(
        openKernelHeight,
      );
      assert.isOk(
        isProposalSetInitialized,
      );
    });
  });
});
