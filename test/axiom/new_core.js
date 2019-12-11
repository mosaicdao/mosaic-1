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
const AxiomUtils = require('./utils.js');
const ProxyTruffleArtifact = require('../../artifacts/Proxy.json');

const SpyConsensus = artifacts.require('SpyConsensus');
const SpyReputation = artifacts.require('SpyReputation');
const SpyCore = artifacts.require('SpyCore');
const SpyAnchor = artifacts.require('SpyAnchor');

const epochLength = new BN(100);
let constructionParams = {};
let contracts = {};
let config = {};
let axiom;
let mockedConsensus;
let callData;
let newCoreParams;

contract('Axiom::newCore', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    contracts = {
      SpyConsensus: await SpyConsensus.new(),
      SpyReputation: await SpyReputation.new(),
      SpyCore: await SpyCore.new(),
      SpyAnchor: await SpyAnchor.new(),
    };
    Object.freeze(contracts);

    constructionParams = {
      techGov: accountProvider.get(),
      consensusMasterCopy: contracts.SpyConsensus.address,
      coreMasterCopy: contracts.SpyCore.address,
      committeeMasterCopy: accountProvider.get(),
      reputationMasterCopy: contracts.SpyReputation.address,
      anchorMasterCopy: contracts.SpyAnchor.address,
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(constructionParams);

    config = {
      committeeSize: new BN(3),
      minValidators: new BN(4),
      joinLimit: new BN(10),
      gasTargetDelta: new BN(1000000000000000),
      coinbaseSplitPermille: new BN(50),
      mOST: accountProvider.get(),
      stakeMOSTAmount: new BN(300000),
      wETH: accountProvider.get(),
      stakeWETHAmount: new BN(300000),
      cashableEarningsPerMille: new BN(12),
      initialReputation: new BN(500),
      withdrawalCooldownPeriodInBlocks: new BN(30),
      txOptions: {
        from: constructionParams.techGov,
      },
    };
    Object.freeze(config);

    axiom = await AxiomUtils.deployAxiomWithConfig(constructionParams);
    await AxiomUtils.setupConsensusWithConfig(axiom, config);
    const mockedConsensusAddress = await axiom.consensus.call();
    mockedConsensus = await SpyConsensus.at(mockedConsensusAddress);

    const mockedReputationAddress = await axiom.reputation.call();

    newCoreParams = {
      consensus: accountProvider.get(),
      metachainId: Utils.getRandomHash(),
      epochLength,
      minValidators: config.minValidators,
      joinLimit: config.joinLimit,
      reputation: mockedReputationAddress,
      height: new BN(Utils.getRandomNumber(1000)),
      parent: Utils.getRandomHash(),
      gasTarget: new BN(Utils.getRandomNumber(999999)),
      dynasty: new BN(Utils.getRandomNumber(10)),
      accumulatedGas: new BN(Utils.getRandomNumber(999999)),
      sourceBlockHeight: new BN(Utils.getRandomNumber(1000)),
    };
    Object.freeze(newCoreParams);

    callData = await AxiomUtils.encodeNewCoreParams(newCoreParams);
  });

  contract('Negative Tests', () => {
    it('should fail when caller is not consensus contract address', async () => {
      await Utils.expectRevert(
        axiom.newCore(callData),
        'Only the consensus contract can call this function.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should deploy proxy contact address', async () => {
      await mockedConsensus.callNewCore(
        axiom.address,
        callData,
      );
    });

    it('should return deployed contract address', async () => {
      await mockedConsensus.callNewCore(
        axiom.address,
        callData,
      );

      const deployedContractAddress = await mockedConsensus.deployedContractAddress.call();
      assert.strictEqual(
        Utils.isNonNullAddress(deployedContractAddress),
        true,
        'Deployed contract address must be a valid ethereum address.',
      );

      const contractByteCode = await Utils.getCode(deployedContractAddress);
      assert.strictEqual(
        contractByteCode,
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy contract byte code must match the compiled binary.',
      );
    });

    it('deployed proxy contract should have the correct master copy address', async () => {
      await mockedConsensus.callNewCore(
        axiom.address,
        callData,
      );

      const deployedContractAddress = await mockedConsensus.deployedContractAddress.call();
      const masterCopyAddress = await Utils.getStorageAt(deployedContractAddress, 0);

      assert.strictEqual(
        Utils.toChecksumAddress(masterCopyAddress),
        contracts.SpyCore.address,
        'Master copy address is not set.',
      );
    });

    it('Check if the core contract was called with correct setup params', async () => {
      await mockedConsensus.callNewCore(
        axiom.address,
        callData,
      );

      const deployedContractAddress = await mockedConsensus.deployedContractAddress.call();
      const spyCore = await SpyCore.at(deployedContractAddress);

      const spyConsensus = await spyCore.spyConsensus.call();
      assert.strictEqual(
        spyConsensus,
        newCoreParams.consensus,
        'Consensus address in spy core contract is not set.',
      );

      const spyMetachainId = await spyCore.spyMetachainId.call();
      assert.strictEqual(
        spyMetachainId,
        newCoreParams.metachainId,
        'Metachain id value in spy core contract is not set.',
      );

      const spyEpochLength = await spyCore.spyEpochLength.call();
      assert.strictEqual(
        spyEpochLength.eq(newCoreParams.epochLength),
        true,
        'Epoch length value in spy core contract is not set.',
      );

      const spyMinValidators = await spyCore.spyMinValidators.call();
      assert.strictEqual(
        spyMinValidators.eq(newCoreParams.minValidators),
        true,
        'Min validator value in spy core contract is not set.',
      );

      const spyJoinLimit = await spyCore.spyJoinLimit.call();
      assert.strictEqual(
        spyJoinLimit.eq(newCoreParams.joinLimit),
        true,
        'Join limit value in spy core contract is not set.',
      );

      const spyReputation = await spyCore.spyReputation.call();
      assert.strictEqual(
        spyReputation,
        newCoreParams.reputation,
        'Reputation contract address in spy core contract is not set.',
      );

      const spyHeight = await spyCore.spyHeight.call();
      assert.strictEqual(
        spyHeight.eq(newCoreParams.height),
        true,
        'Height value in spy core contract is not set.',
      );

      const spyParent = await spyCore.spyParent.call();
      assert.strictEqual(
        spyParent,
        newCoreParams.parent,
        'Parent value in spy core contract is not set.',
      );

      const spyGasTarget = await spyCore.spyGasTarget.call();
      assert.strictEqual(
        spyGasTarget.eq(newCoreParams.gasTarget),
        true,
        'Gas target value in spy core contract is not set.',
      );

      const spyDynasty = await spyCore.spyDynasty.call();
      assert.strictEqual(
        spyDynasty.eq(newCoreParams.dynasty),
        true,
        'Dynasty value in spy core contract is not set.',
      );

      const spyAccumulatedGas = await spyCore.spyAccumulatedGas.call();
      assert.strictEqual(
        spyAccumulatedGas.eq(newCoreParams.accumulatedGas),
        true,
        'Accumulated gas value in spy core contract is not set.',
      );

      const spySourceBlockHeight = await spyCore.spySourceBlockHeight.call();
      assert.strictEqual(
        spySourceBlockHeight.eq(newCoreParams.sourceBlockHeight),
        true,
        'Source block value in spy core contract is not set.',
      );
    });
  });
});
