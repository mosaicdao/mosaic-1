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
const Utils = require('../test_lib/utils.js');
const CoreUtils = require('./utils.js');

const MockCore = artifacts.require('MockCore');

const config = {};

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

contract('Core::join', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.consensusCoreArgs = {
      chainId: accountProvider.get(),
      epochLength: new BN(100),
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

    config.newValidator0 = accountProvider.get();
    config.newValidator1 = accountProvider.get();
  });

  contract('Negative Tests', async () => {
    it('should fail if a caller is not consensus', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );

      await Utils.expectRevert(
        config.core.join(
          config.newValidator0,
        ),
        'Only the consensus contract can call this function.',
      );
    });

    it('should fail if core is not in a running state', async () => {
      await Utils.expectRevert(
        config.consensus.join(
          config.newValidator0,
        ),
        'The core must be running.',
      );
    });

    it('should fail if validators\' join limit for the core was reached', async () => {
      const { validators } = await CoreUtils.openCore(
        config.consensus, config.core,
      );

      const countValidators = await config.core.countValidators();
      assert(countValidators > 0);

      const joinLimit = await config.core.joinLimit();
      assert(joinLimit > 0);

      assert(countValidators < joinLimit);

      const joinValidatorsCount = new BN(3);
      for (let i = 0; i < joinValidatorsCount.toNumber(); i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await config.consensus.join(accountProvider.get());
      }

      const loggedOutValidatorsCount = new BN(2);
      assert(validators.length >= loggedOutValidatorsCount);
      for (let i = 0; i < loggedOutValidatorsCount.toNumber(); i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await config.consensus.logout(validators[i].address);
      }

      for (
        let i = 0;
        i < joinLimit.sub(
          countValidators.add(joinValidatorsCount).sub(loggedOutValidatorsCount),
        ).toNumber();
        i += 1
      ) {
        // eslint-disable-next-line no-await-in-loop
        await config.consensus.join(accountProvider.get());
      }

      await Utils.expectRevert(
        config.consensus.join(
          accountProvider.get(),
        ),
        'Join limit is reached for this core.',
      );
    });

    it('should fail if an address of the given validator is 0', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );

      await Utils.expectRevert(
        config.consensus.join(
          Utils.NULL_ADDRESS,
        ),
        'Validator must not be null address.',
      );
    });

    it('should fail if a validator has already joined', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );

      await config.consensus.join(
        config.newValidator0,
      );

      await Utils.expectRevert(
        config.consensus.join(
          config.newValidator0,
        ),
        'Validator must not already be part of this core.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should join a validator', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );

      const openKernelHeight = await config.core.openKernelHeight();
      const nextKernelHeight = openKernelHeight.addn(1);

      const previousCountJoinMessages = await config.core.countJoinMessages();
      const previousUpdatedValidators = await config.core.updatedValidators(nextKernelHeight);
      const previousUpdatedReputations = await config.core.updatedReputations(nextKernelHeight);

      await config.consensus.join(config.newValidator0);

      const currentCountJoinMessages = await config.core.countJoinMessages();
      const currentUpdatedValidators = await config.core.updatedValidators(nextKernelHeight);
      const currentUpdatedReputations = await config.core.updatedReputations(nextKernelHeight);

      assert.isOk(
        currentCountJoinMessages.eq(previousCountJoinMessages.addn(1)),
      );

      assert.strictEqual(
        currentUpdatedValidators.length,
        previousUpdatedValidators.length + 1,
      );

      assert.strictEqual(
        currentUpdatedReputations.length,
        previousUpdatedReputations.length + 1,
      );

      const validatorIndex = currentUpdatedValidators.findIndex(
        el => el === config.newValidator0,
      );
      assert.notStrictEqual(
        validatorIndex,
        -1,
      );
      assert.isOk(
        currentUpdatedReputations[validatorIndex].eqn(1),
      );

      const maxFutureEndHeight = await config.core.MAX_FUTURE_END_HEIGHT();
      await assertValidatorHeight(
        config.core,
        config.newValidator0,
        nextKernelHeight,
        maxFutureEndHeight,
      );
    });
  });
});
