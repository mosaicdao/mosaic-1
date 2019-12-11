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
const AxiomUtils = require('./utils.js');
const Utils = require('../test_lib/utils.js');
const ProxyTruffleArtifact = require('../../artifacts/Proxy.json');

const SpyReputation = artifacts.require('SpyReputation');
const SpyConsensus = artifacts.require('SpyConsensus');
const SpyAnchor = artifacts.require('SpyAnchor');

let config = {};
let contracts = {};
let constructionParams = {};
let axiom;
contract('Axiom::setupConsensus', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    contracts = {
      SpyConsensus: await SpyConsensus.new(),
      SpyReputation: await SpyReputation.new(),
      SpyAnchor: await SpyAnchor.new(),
    };
    Object.freeze(contracts);

    constructionParams = {
      techGov: accountProvider.get(),
      consensusMasterCopy: contracts.SpyConsensus.address,
      coreMasterCopy: accountProvider.get(),
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
  });

  contract('Negative Tests', () => {
    it('should fail to setup consensus twice', async () => {
      await AxiomUtils.setupConsensusWithConfig(axiom, config);

      await Utils.expectRevert(
        AxiomUtils.setupConsensusWithConfig(axiom, config),
        'Consensus is already setup.',
      );
    });

    it('should fail called by non technical governance address.', async () => {
      config = Object.assign(
        {},
        config,
        {
          txOptions: {
            from: accountProvider.get(),
          },
        },
      );
      await Utils.expectRevert(
        AxiomUtils.setupConsensusWithConfig(axiom, config),
        'Caller must be technical governance address.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should deploy consensus proxy contract with consensus contract master copy', async () => {
      await AxiomUtils.setupConsensusWithConfig(axiom, config);
      const consensusContractAddress = await axiom.consensus.call();
      assert.strictEqual(
        Utils.isAddress(consensusContractAddress),
        true,
        'Invalid proxy consensus contract address.',
      );

      const contractByteCode = await Utils.getCode(consensusContractAddress);
      assert.strictEqual(
        contractByteCode,
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy contract byte code must match the compiled binary.',
      );

      const consensusProxyContract = await SpyConsensus.at(consensusContractAddress);
      const masterCopyAddress = await consensusProxyContract.getReservedStorageSlotForProxy.call();
      assert.strictEqual(
        masterCopyAddress,
        constructionParams.consensusMasterCopy,
        'Consensus master copy address must be same as the one provided while setup.',
      );
    });

    it('should deploy reputation proxy contract with reputation contract master copy', async () => {
      await AxiomUtils.setupConsensusWithConfig(axiom, config);
      const reputationContractAddress = await axiom.reputation.call();
      assert.strictEqual(
        Utils.isAddress(reputationContractAddress),
        true,
        'Invalid proxy consensus contract address.',
      );

      const contractByteCode = await Utils.getCode(reputationContractAddress);
      assert.strictEqual(
        contractByteCode,
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy contract byte code must match the compiled binary.',
      );

      const reputationProxyContract = await SpyReputation.at(reputationContractAddress);
      const masterCopyAddress = await reputationProxyContract.getReservedStorageSlotForProxy.call();
      assert.strictEqual(
        masterCopyAddress,
        constructionParams.reputationMasterCopy,
        'Reputation master copy address must be same as the one provided while setup.',
      );
    });

    it('should validate the spied values of the consensus proxy contract', async () => {
      await AxiomUtils.setupConsensusWithConfig(axiom, config);
      const consensusContractAddress = await axiom.consensus.call();
      const consensusProxyContract = await SpyConsensus.at(consensusContractAddress);

      const committeeSize = await consensusProxyContract.committeeSize.call();
      assert.strictEqual(
        committeeSize.eq(config.committeeSize),
        true,
        'Committee size value is not set in the contract.',
      );

      const minValidators = await consensusProxyContract.minValidators.call();
      assert.strictEqual(
        minValidators.eq(config.minValidators),
        true,
        'Min validators value is not set in the contract.',
      );

      const joinLimit = await consensusProxyContract.joinLimit.call();
      assert.strictEqual(
        joinLimit.eq(config.joinLimit),
        true,
        'Join limit value is not set in the contract.',
      );

      const gasTargetDelta = await consensusProxyContract.gasTargetDelta.call();
      assert.strictEqual(
        gasTargetDelta.eq(config.gasTargetDelta),
        true,
        'Gas target delta value is not set in the contract.',
      );

      const coinbaseSplitPermille = await consensusProxyContract.coinbaseSplitPerMille.call();
      assert.strictEqual(
        coinbaseSplitPermille.eq(config.coinbaseSplitPermille),
        true,
        'Coin base split percentage value is not set in the contract.',
      );

      const reputation = await consensusProxyContract.reputation.call();
      const reputationContractAddress = await axiom.reputation.call();
      assert.strictEqual(
        reputation,
        reputationContractAddress,
        'Reputation value is not set in the contract.',
      );
    });

    it('should validate the spied values of the reputation proxy contract', async () => {
      await AxiomUtils.setupConsensusWithConfig(axiom, config);
      const reputationContractAddress = await axiom.reputation.call();
      const reputationProxyContract = await SpyReputation.at(reputationContractAddress);

      const consensus = await reputationProxyContract.consensus.call();
      const consensusContractAddress = await axiom.consensus.call();
      assert.strictEqual(
        consensus,
        consensusContractAddress,
        'Consensus contract address is not set in the contract.',
      );

      const mOST = await reputationProxyContract.mOST.call();
      assert.strictEqual(
        mOST,
        config.mOST,
        'mOST contract address is not set in the contract.',
      );

      const stakeMOSTAmount = await reputationProxyContract.stakeMOSTAmount.call();
      assert.strictEqual(
        stakeMOSTAmount.eq(config.stakeMOSTAmount),
        true,
        'Stake mOST amount is not set in the contract.',
      );

      const wETH = await reputationProxyContract.wETH.call();
      assert.strictEqual(
        wETH,
        config.wETH,
        'wETH contract address is not set in the contract.',
      );

      const stakeWETHAmount = await reputationProxyContract.stakeWETHAmount.call();
      assert.strictEqual(
        stakeWETHAmount.eq(config.stakeWETHAmount),
        true,
        'Stake wETH amount is not set in the contract.',
      );

      const cashableEarningsPerMille = await reputationProxyContract
        .cashableEarningsPerMille
        .call();

      assert.strictEqual(
        cashableEarningsPerMille.eq(config.cashableEarningsPerMille),
        true,
        'Cashable earnings per mille value is not set in the contract.',
      );

      const initialReputation = await reputationProxyContract.initialReputation.call();
      assert.strictEqual(
        initialReputation.eq(config.initialReputation),
        true,
        'Initial reputation value is not set in the contract.',
      );

      const withdrawalCooldownPeriodInBlocks = await reputationProxyContract
        .withdrawalCooldownPeriodInBlocks
        .call();

      assert.strictEqual(
        withdrawalCooldownPeriodInBlocks.eq(config.withdrawalCooldownPeriodInBlocks),
        true,
        'Withdrawal cooldown period in blocks value is not set in the contract.',
      );
    });
  });
});
