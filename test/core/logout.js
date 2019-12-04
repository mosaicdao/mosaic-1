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

contract('Core::logout', async (accounts) => {
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
  });

  contract('Negative Tests', async () => {
    it('should fail if a caller is not consensus', async () => {
      const { validators } = await CoreUtils.openCore(
        config.consensus, config.core,
      );

      const validator = validators[0].address;

      await Utils.expectRevert(
        config.core.logout(
          validator,
        ),
        'Only the consensus contract can call this function.',
      );
    });

    it('should fail if core is not in a running state', async () => {
      await Utils.expectRevert(
        config.consensus.logout(
          accountProvider.get(),
        ),
        'The core must be running.',
      );
    });

    it('should fail if validators\' minimum limit was reached', async () => {
      const { validators } = await CoreUtils.openCore(
        config.consensus, config.core,
      );

      const countValidators = await config.core.countValidators();
      assert(countValidators.gtn(0));

      const minimumValidatorCount = await config.core.minimumValidatorCount();
      assert(minimumValidatorCount.gtn(0));

      assert(countValidators.gte(minimumValidatorCount));

      const joinValidatorsCount = new BN(3);
      for (let i = 0; i < joinValidatorsCount.toNumber(); i += 1) {
        const v = accountProvider.get();
        // eslint-disable-next-line no-await-in-loop
        await config.consensus.join(v);
        validators.push({ address: v });
      }

      let index = 0;
      for (
        ;
        index < countValidators.add(
          joinValidatorsCount,
        ).sub(minimumValidatorCount).toNumber();
        index += 1
      ) {
        // eslint-disable-next-line no-await-in-loop
        await config.consensus.logout(validators[index].address);
      }

      await Utils.expectRevert(
        config.consensus.logout(
          validators[index].address,
        ),
        'Validator minimum limit reached.',
      );
      index += 1;
    });

    it('should fail if an address of the given validator is 0', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );
      await config.consensus.join(accountProvider.get());

      await Utils.expectRevert(
        config.consensus.logout(
          Utils.NULL_ADDRESS,
        ),
        'Validator must not be null address.',
      );
    });

    it('should fail if validator has not begun', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );
      await config.consensus.join(accountProvider.get());

      const validator = accountProvider.get();
      await config.consensus.join(validator);

      await Utils.expectRevert(
        config.consensus.logout(
          validator,
        ),
        'Validator must have begun.',
      );
    });

    it('should fail if validator is not active', async () => {
      await CoreUtils.openCore(
        config.consensus, config.core,
      );
      await config.consensus.join(accountProvider.get());

      await Utils.expectRevert(
        config.consensus.logout(
          accountProvider.get(),
        ),
        'Validator must be active.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should logout a validator', async () => {
      const { validators } = await CoreUtils.openCore(
        config.consensus, config.core,
      );
      await config.consensus.join(accountProvider.get());

      const validator = validators[0].address;

      const openKernelHeight = await config.core.openKernelHeight();
      const nextKernelHeight = openKernelHeight.addn(1);

      const previousCountLogOutMessages = await config.core.countLogOutMessages();
      const previousUpdatedValidators = await config.core.updatedValidators(nextKernelHeight);
      const previousUpdatedReputations = await config.core.updatedReputations(nextKernelHeight);

      await config.consensus.logout(validator);

      const currentCountLogOutMessages = await config.core.countLogOutMessages();
      const currentUpdatedValidators = await config.core.updatedValidators(nextKernelHeight);
      const currentUpdatedReputations = await config.core.updatedReputations(nextKernelHeight);

      assert.isOk(
        currentCountLogOutMessages.eq(previousCountLogOutMessages.addn(1)),
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
        el => el === validator,
      );
      assert.notStrictEqual(
        validatorIndex,
        -1,
      );
      assert.isOk(
        currentUpdatedReputations[validatorIndex].eqn(0),
      );

      await assertValidatorHeight(
        config.core,
        validator,
        openKernelHeight,
        nextKernelHeight,
      );
    });
  });
});
