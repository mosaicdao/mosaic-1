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
const SpyCommittee = artifacts.require('SpyCommittee');
const SpyAnchor = artifacts.require('SpyAnchor');

let constructionParams = {};
let contracts = {};
let config = {};
let axiom;
let mockedConsensus;
let callData;
let newCommitteeParams;

contract('Axiom::newCommittee', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    contracts = {
      SpyConsensus: await SpyConsensus.new(),
      SpyReputation: await SpyReputation.new(),
      SpyCommittee: await SpyCommittee.new(),
      SpyAnchor: await SpyAnchor.new(),
    };
    Object.freeze(contracts);

    constructionParams = {
      techGov: accountProvider.get(),
      consensusMasterCopy: contracts.SpyConsensus.address,
      coreMasterCopy: accountProvider.get(),
      committeeMasterCopy: contracts.SpyCommittee.address,
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

    newCommitteeParams = {
      consensus: accountProvider.get(),
      committeeSize: new BN(Utils.getRandomNumber(1000)),
      dislocation: Utils.getRandomHash(),
      proposal: Utils.getRandomHash(),
    };
    Object.freeze(newCommitteeParams);

    callData = await AxiomUtils.encodeNewCommitteeParams(newCommitteeParams);
  });

  contract('Negative Tests', () => {
    it('should fail when caller is not consensus contract address', async () => {
      await Utils.expectRevert(
        axiom.newCommittee(callData),
        'Only the consensus contract can call this function.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should deploy proxy contract address', async () => {
      await mockedConsensus.callNewCommittee(
        axiom.address,
        callData,
      );
    });

    it('should return deployed contract address', async () => {
      await mockedConsensus.callNewCommittee(
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
      await mockedConsensus.callNewCommittee(
        axiom.address,
        callData,
      );

      const deployedContractAddress = await mockedConsensus.deployedContractAddress.call();
      const masterCopyAddress = await Utils.getStorageAt(deployedContractAddress, 0);

      assert.strictEqual(
        Utils.toChecksumAddress(masterCopyAddress),
        contracts.SpyCommittee.address,
        'Master copy address is not set.',
      );
    });

    it('Check if the core contract was called with correct setup params', async () => {
      await mockedConsensus.callNewCommittee(
        axiom.address,
        callData,
      );

      const deployedContractAddress = await mockedConsensus.deployedContractAddress.call();
      const spyCommittee = await SpyCommittee.at(deployedContractAddress);

      const spyConsensus = await spyCommittee.spyConsensus.call();
      assert.strictEqual(
        spyConsensus,
        newCommitteeParams.consensus,
        'Consensus address in spy core contract is not set.',
      );

      const spyCommitteeSize = await spyCommittee.spyCommitteeSize.call();
      assert.strictEqual(
        spyCommitteeSize.eq(newCommitteeParams.committeeSize),
        true,
        'Committee size value in spy core contract is not set.',
      );

      const spyDislocation = await spyCommittee.spyDislocation.call();
      assert.strictEqual(
        spyDislocation,
        newCommitteeParams.dislocation,
        'Dislocation value in spy core contract is not set.',
      );

      const spyProposal = await spyCommittee.spyProposal.call();
      assert.strictEqual(
        spyProposal,
        newCommitteeParams.proposal,
        'Proposal value in spy core contract is not set.',
      );
    });
  });
});
