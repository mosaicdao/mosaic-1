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

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const CoconsensusUtils = require('./utils');
const ProtocoreUtils = require('../protocore/utils');

const ConsensusCogatewaySpy = artifacts.require('ConsensusCogatewaySpy');
const CoreputationSpy = artifacts.require('CoreputationSpy');

contract('Coconsensus::commitCheckpoint', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  const config = {};

  beforeEach(async () => {
    const { deployCoconsensus } = CoconsensusUtils;
    Object.assign(config, await deployCoconsensus(accountProvider));

    const { contracts } = config;
    contracts.consensusCogatewaySpy = await ConsensusCogatewaySpy.new();
    contracts.coreputationSpy = await CoreputationSpy.new();

    const { coconsensus } = contracts;

    await coconsensus.setCoreputation(contracts.coreputationSpy.address);
    await coconsensus.setConsensusCogateway(contracts.consensusCogatewaySpy.address);
  });

  contract('Positive Tests', async () => {
    it('should commit the checkpoint and update the open kernel hash and open kernel height', async () => {
      const { coconsensus, selfProtocore, consensusCogatewaySpy } = config.contracts;

      const data = config.genesis.protocoreData[config.genesis.auxiliaryMetachainId].genesis;
      let sourceBlockNumber = data.auxiliarySourceBlockNumber;
      let sourceBlockHash = data.auxiliarySourceBlockHash;
      let targetBlockHash = data.auxiliaryTargetBlockHash;
      let targetBlockNumber = data.auxiliaryTargetBlockNumber;
      let updatedValidators = [];
      let updatedReputation = [];
      let kernelHeight = new BN(-1);
      let gasTarget = new BN(100);
      let transitionHash = data.auxiliarySourceTransitionHash;

      const finalizedCheckpoints = [];

      for (let i = 0; i < 3; i += 1) {
        const parent = ProtocoreUtils.hashVoteMessage(
          data.domainSeparator,
          transitionHash,
          sourceBlockHash,
          targetBlockHash,
          sourceBlockNumber,
          targetBlockNumber,
        );

        kernelHeight = new BN(i);

        gasTarget = gasTarget.addn(Utils.getRandomNumber(1000));

        updatedValidators = [
          accountProvider.get(),
          accountProvider.get(),
          accountProvider.get(),
        ];

        updatedReputation = [
          Utils.getRandomNumber(100),
          Utils.getRandomNumber(100),
          Utils.getRandomNumber(100),
        ];

        const kernelHash = CoconsensusUtils.hashKernel(
          kernelHeight,
          parent,
          updatedValidators,
          updatedReputation,
          gasTarget,
          data.domainSeparator,
        );

        // eslint-disable-next-line no-await-in-loop
        await consensusCogatewaySpy.setKernelHash(kernelHash, kernelHeight);

        const inputParams = {
          kernelHeight,
          updatedValidators,
          updatedReputation,
          gasTarget,
          transitionHash,
          sourceBlockHash,
          targetBlockHash,
          sourceBlockNumber,
          targetBlockNumber,
          kernelHash,
        };

        finalizedCheckpoints.push(inputParams);

        sourceBlockNumber = targetBlockNumber;
        sourceBlockHash = targetBlockHash;
        targetBlockNumber = sourceBlockNumber.add(data.epochLength);
        targetBlockHash = Utils.getRandomHash();
        transitionHash = Utils.getRandomHash();

        // eslint-disable-next-line no-await-in-loop
        await selfProtocore.testFinaliseCheckpoint(
          config.genesis.auxiliaryMetachainId,
          targetBlockNumber,
          targetBlockHash,
        );
      }

      for (let i = 1; i < finalizedCheckpoints.length; i += 1) {
        const params = finalizedCheckpoints[i];

        // eslint-disable-next-line no-await-in-loop
        await coconsensus.commitCheckpoint(
          config.genesis.auxiliaryMetachainId,
          params.kernelHeight,
          params.updatedValidators,
          params.updatedReputation,
          params.gasTarget,
          params.transitionHash,
          params.sourceBlockHash,
          params.targetBlockHash,
          params.sourceBlockNumber,
          params.targetBlockNumber,
        );

        // eslint-disable-next-line no-await-in-loop
        const spyKernelHeight = await consensusCogatewaySpy.spyKernelHeight();

        assert.isOk(
          spyKernelHeight.eq(params.kernelHeight),
          `spyKernelHeight value must be set with value ${params.kernelHeight}`,
        );

        // eslint-disable-next-line no-await-in-loop
        const openKernelHeight = await selfProtocore.openKernelHeight();
        assert.isOk(
          openKernelHeight.eq(params.kernelHeight),
          `Open kernel height must be equal to ${params.kernelHeight}`,
        );

        // eslint-disable-next-line no-await-in-loop
        const openKernelHash = await selfProtocore.openKernelHash();
        assert.strictEqual(
          openKernelHash,
          params.kernelHash,
          'Open kernel height must be set',
        );
      }
    });
  });
});
