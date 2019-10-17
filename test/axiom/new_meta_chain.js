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
const AnchorTruffleArtifact = require('../../build/contracts/Anchor.json');


const SpyConsensus = artifacts.require('SpyConsensus');
const SpyReputation = artifacts.require('SpyReputation');

let config = {};
let contracts = {};
let constructionParams = {};
let newMetaChainParams = {};
let axiom;

contract('Axiom::newMetaChain', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    contracts = {
      SpyConsensus: await SpyConsensus.new(),
      SpyReputation: await SpyReputation.new(),
    };

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

    newMetaChainParams = {
      epochLength: new BN(3),
      source: Utils.getRandomHash(),
      sourceBlockHeight: new BN(3000),
      remoteChainId: new BN(1405),
      stateRoot: Utils.getRandomHash(),
      maxStateRoots: new BN(10),
      txOptions: {
        from: constructionParams.techGov,
      },
    };
    Object.freeze(newMetaChainParams);
  });

  contract('Negative Tests', () => {
    it('should fail when called by non technical governance address', async () => {
      newMetaChainParams = Object.assign(
        {},
        newMetaChainParams,
        {
          txOptions: {
            from: accountProvider.get(),
          },
        },
      );
      await Utils.expectRevert(
        AxiomUtils.newMetaChainWithConfig(axiom, newMetaChainParams),
        'Caller must be technical governance address.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should pass when called with correct params', async () => {
      await AxiomUtils.newMetaChainWithConfig(axiom, newMetaChainParams);
    });

    it('should deploy anchor contract', async () => {
      await AxiomUtils.newMetaChainWithConfig(axiom, newMetaChainParams);

      const consensusContractAddress = await axiom.consensus.call();
      const consensusProxyContract = await SpyConsensus.at(consensusContractAddress);


      const chainId = await consensusProxyContract.chainId.call();
      const contractByteCode = await Utils.getCode(chainId);
      assert.strictEqual(
        contractByteCode,
        AnchorTruffleArtifact.deployedBytecode,
        'Anchor contract byte code must match the compiled binary.',
      );
    });

    it('should validate the spied values of the consensus proxy contract', async () => {
      await AxiomUtils.newMetaChainWithConfig(axiom, newMetaChainParams);

      const consensusContractAddress = await axiom.consensus.call();
      const consensusProxyContract = await SpyConsensus.at(consensusContractAddress);

      const epochLength = await consensusProxyContract.epochLength.call();
      assert.strictEqual(
        epochLength.eq(newMetaChainParams.epochLength),
        true,
        'Epoch length value is not set in the contract.',
      );

      const source = await consensusProxyContract.source.call();
      assert.strictEqual(
        source,
        newMetaChainParams.source,
        'Source value is not set in the contract.',
      );

      const sourceBlockHeight = await consensusProxyContract.sourceBlockHeight.call();
      assert.strictEqual(
        sourceBlockHeight.eq(newMetaChainParams.sourceBlockHeight),
        true,
        'Source block height value is not set in the contract.',
      );

    });
  });
});
