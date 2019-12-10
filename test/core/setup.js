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
const CoreStatusUtils = require('../test_lib/core_status_utils.js');
const Utils = require('../test_lib/utils.js');

const CoreUtils = require('./utils.js');

let correctArgs = {};
let config = {};

async function createCore(args, consensus) {
  return CoreUtils.createCore(
    consensus,
    args.metachainId,
    args.epochLength,
    args.minValidators,
    args.joinLimit,
    args.reputation,
    args.height,
    args.parent,
    args.gasTarget,
    args.dynasty,
    args.accumulatedGas,
    args.sourceBlockHeight,
    {
      from: consensus,
    },
  );
}

contract('Core::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    correctArgs = {
      metachainId: Utils.getRandomHash(),
      epochLength: new BN(100),
      minValidators: new BN(3),
      joinLimit: new BN(5),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(0),
      dynasty: new BN(0),
      accumulatedGas: new BN(1),
      source: CoreUtils.randomSha3(),
      sourceBlockHeight: new BN(0),
      reputation: accountProvider.get(),
    };

    config = {
      consensus: accountProvider.get(),
    };
    Object.freeze(config);
  });

  contract('Negative Tests', async () => {
    it('should revert as metachain id is 0', async () => {
      const args = correctArgs;
      args.metachainId = Utils.ZERO_BYTES32;

      await Utils.expectRevert(
        createCore(args, config.consensus),
        'Metachain id is 0.',
      );
    });

    it('should revert as epoch length is 0', async () => {
      const args = correctArgs;
      args.epochLength = 0;

      await Utils.expectRevert(
        createCore(args, config.consensus),
        'Epoch length is 0.',
      );
    });

    it('should revert as min validators\' count is 0', async () => {
      const args = correctArgs;
      args.minValidators = 0;

      await Utils.expectRevert(
        createCore(args, config.consensus),
        'Min validators count is 0.',
      );
    });

    it('should revert as reputation\'s contract address is 0', async () => {
      const args = correctArgs;
      args.reputation = Utils.NULL_ADDRESS;

      await Utils.expectRevert(
        createCore(args, config.consensus),
        'Reputation contract\'s address is null.',
      );
    });

    it('should revert as height is 0 and parent is not', async () => {
      const args = correctArgs;
      args.height = 0;
      args.parent = CoreUtils.randomSha3();

      await Utils.expectRevert(
        createCore(args, config.consensus),
        'Height and parent can be 0 only together.',
      );
    });

    it('should revert as parent is 0 and height is not', async () => {
      const args = correctArgs;
      args.height = 1;
      args.parent = Utils.ZERO_BYTES32;

      await Utils.expectRevert(
        createCore(args, config.consensus),
        'Height and parent can be 0 only together.',
      );
    });

  contract('Positive Tests', async () => {
    it('should construct with correct arguments', async () => {
      const core = await createCore(correctArgs, config.consensus);

      const consensus = await core.consensus();
      assert.strictEqual(
        consensus,
        config.consensus,
        `Consensus contract is set to ${consensus} and is not ${config.consensus}.`,
      );

      const coreStatus = await core.coreStatus();
      assert.isOk(
        CoreStatusUtils.isCoreCreated(coreStatus),
        'Core status should be set to created on construction.',
      );

      const epochLength = await core.epochLength();
      assert.isOk(
        epochLength.cmp(correctArgs.epochLength) === 0,
        `Epoch length is set to ${epochLength} and is not ${correctArgs.epochLength}`,
      );

      const reputation = await core.reputation();
      assert.strictEqual(
        reputation,
        correctArgs.reputation,
        `Reputation is set to ${reputation} and is not ${correctArgs.reputation}`,
      );

      const minimumValidatorCount = await core.minimumValidatorCount();
      assert.isOk(
        minimumValidatorCount.cmp(correctArgs.minValidators) === 0,
        `Min validators's count is set to ${minimumValidatorCount} `
        + `and is not ${correctArgs.minValidators}`,
      );

      const joinLimit = await core.joinLimit();
      assert.isOk(
        joinLimit.cmp(correctArgs.joinLimit) === 0,
        `Join limit is set to ${joinLimit} and is not ${correctArgs.joinLimit}`,
      );

      const creationKernelHeight = await core.creationKernelHeight();
      assert.isOk(
        creationKernelHeight.cmp(correctArgs.height) === 0,
        `Creation kernel height is set to ${creationKernelHeight} `
        + `and is not ${correctArgs.height}`,
      );

      const kernel = await core.kernels(correctArgs.height);
      assert.strictEqual(
        kernel.parent,
        correctArgs.parent,
        `Creation kernel's parent is set to ${kernel.parent} and is not ${correctArgs.parent}`,
      );

      assert.isOk(
        kernel.gasTarget.cmp(correctArgs.gasTarget) === 0,
        `Creation kernel's gas target is set to ${kernel.gasTarget} `
        + `and is not ${correctArgs.gasTarget}`,
      );

      const committedDynasty = await core.committedDynasty();
      assert.isOk(
        committedDynasty.cmp(correctArgs.dynasty) === 0,
        `Dynasty is set to ${committedDynasty} and is not ${correctArgs.dynasty}`,
      );

      const committedAccumulatedGas = await core.committedAccumulatedGas();
      assert.isOk(
        committedAccumulatedGas.cmp(correctArgs.accumulatedGas) === 0,
        `Accumulated gas is set to ${committedAccumulatedGas} `
        + `and is not ${correctArgs.accumulatedGas}`,
      );

      const committedSourceBlockHeight = await core.committedSourceBlockHeight();
      assert.isOk(
        committedSourceBlockHeight.cmp(correctArgs.sourceBlockHeight) === 0,
        `Source block height is set to ${committedSourceBlockHeight} `
        + `and is not ${correctArgs.sourceBlockHeight}`,
      );
    });
  });
});
