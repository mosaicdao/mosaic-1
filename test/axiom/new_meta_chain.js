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
const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');
const AxiomUtils = require('./utils.js');
const ProxyTruffleArtifact = require('../../artifacts/Proxy.json');


const SpyConsensus = artifacts.require('SpyConsensus');
const SpyReputation = artifacts.require('SpyReputation');
const SpyAnchor = artifacts.require('SpyAnchor');

const EPOCH_LENGTH = 100;

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
      SpyAnchor: await SpyAnchor.new(),
    };

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
    axiom = await AxiomUtils.deployAxiomWithConfig(constructionParams);
    await AxiomUtils.setupConsensusWithConfig(axiom, config);

    newMetaChainParams = {
      maxStateRoots: new BN(10),
      rlpBlockHeader: '0xf901f9a083cafc574e1f51ba9dc0568fc617a08ea2429fb384059c972f13b19fa1c8dd55a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347948888f1f195afa192cfee860698584c030f4c9db1a0ef1552a40b7165c3cd773806b9e0c165b75356e0314bf0706f279c729f51e017a05fe50b260da6308036625b850b5d6ced6d0a9f814c0688bc91ffb7b7a3a54b67a0bc37d79753ad738a6dac4921e57392f145d8887476de3f783dfa7edae9283e52b90100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008302000001832fefd8825208845506eb0780a0bd4472abb6659ebe3ee06ee4d7b72a00a9f4d001caca51342001075469aff49888a13a5a8c8f2bb1c4',
      sourceBlockHeight: new BN(1),
      txOptions: {
        from: constructionParams.techGov,
      },
    };
  });

  contract('Negative Tests', () => {
    it('should fail when called by non technical governance address', async () => {
      newMetaChainParams.txOptions.from = accountProvider.get();
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

      const anchorAddress = await consensusProxyContract.anchor.call();
      const contractByteCode = await Utils.getCode(anchorAddress);
      assert.strictEqual(
        contractByteCode,
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy of Anchor contract byte code must match the compiled binary.',
      );

      const anchor = await SpyAnchor.at(anchorAddress);
      const maxStateRootFromAnchor = new BN(await anchor.spyMaxStateRoot.call());
      const consensusFromAnchor = await anchor.spyConsensus.call();

      assert.isOk(
        maxStateRootFromAnchor.eq(newMetaChainParams.maxStateRoots),
        `Max state root from anchor ${maxStateRootFromAnchor.toString(10)}`
        + ` must match to ${newMetaChainParams.maxStateRoots.toString(10)}`,
      );
      assert.strictEqual(
        consensusContractAddress,
        consensusFromAnchor,
        'Consensus address from axiom must match to anchor',
      );
    });

    it('should validate the spied values of the consensus proxy contract', async () => {
      await AxiomUtils.newMetaChainWithConfig(axiom, newMetaChainParams);

      const consensusContractAddress = await axiom.consensus.call();
      const consensusProxyContract = await SpyConsensus.at(consensusContractAddress);

      const epochLength = await consensusProxyContract.epochLength.call();
      assert.strictEqual(
        epochLength.eqn(EPOCH_LENGTH),
        true,
        'Epoch length value is not set in the contract.',
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
