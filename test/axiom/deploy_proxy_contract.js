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
const ProxyTruffleArtifact = require('../../build/contracts/Proxy.json');

const SpyConsensus = artifacts.require('SpyConsensus');
const SpyReputation = artifacts.require('SpyReputation');
const MockMasterCopy = artifacts.require('MockMasterCopy');

const count = 2;
let constructionParams = {};
let contracts = {};
let config = {};
let axiom;
let mockedConsensus;
let callData;

contract('Axiom::deployProxyContract', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    contracts = {
      SpyConsensus: await SpyConsensus.new(),
      SpyReputation: await SpyReputation.new(),
      MockMasterCopy: await MockMasterCopy.new(),
    };
    Object.freeze(contracts);

    constructionParams = {
      techGov: accountProvider.get(),
      consensusMasterCopy: contracts.SpyConsensus.address,
      coreMasterCopy: accountProvider.get(),
      committeeMasterCopy: accountProvider.get(),
      reputationMasterCopy: contracts.SpyReputation.address,
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
      coinbaseSplitPercentage: new BN(50),
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
    callData = await contracts.MockMasterCopy.getSetupData.call(count);
  });

  contract('Negative Tests', () => {
    it('should fail when caller is not consensus contract address', async () => {
      await Utils.expectRevert(
        axiom.deployProxyContract(contracts.MockMasterCopy.address, callData),
        'Caller must be consensus address.',
      );
    });

    it('should fail when master copy address is 0', async () => {
      await Utils.expectRevert(
        mockedConsensus.deployProxyContract(
          axiom.address,
          Utils.NULL_ADDRESS,
          callData,
        ),
        'Master copy address is 0.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should deploy proxy contact address', async () => {
      await mockedConsensus.deployProxyContract(
        axiom.address,
        contracts.MockMasterCopy.address,
        callData,
      );
    });

    it('should return deployed contract address', async () => {
      await mockedConsensus.deployProxyContract(
        axiom.address,
        contracts.MockMasterCopy.address,
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
      await mockedConsensus.deployProxyContract(
        axiom.address,
        contracts.MockMasterCopy.address,
        callData,
      );

      const deployedContractAddress = await mockedConsensus.deployedContractAddress.call();

      const proxyContract = await MockMasterCopy.at(deployedContractAddress);
      const masterCopyAddress = await proxyContract.getReservedStorageSlotForProxy.call();

      assert.strictEqual(
        masterCopyAddress,
        contracts.MockMasterCopy.address,
        'Master copy address is not set.',
      );

      const isSetupCalled = await proxyContract.isSetupCalled.call();
      assert.strictEqual(
        isSetupCalled,
        true,
        'Setup of deployed proxy contract is not called.',
      );

      const mockCount = await proxyContract.mockCount.call();
      assert.strictEqual(
        mockCount.eqn(count),
        true,
        'Mock count in deployed proxy contract is not set.',
      );
    });
  });
});
