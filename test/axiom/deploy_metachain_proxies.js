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

const SpyCore = artifacts.require('SpyCore');
const SpyAnchor = artifacts.require('SpyAnchor');
const SpyConsensusGateway = artifacts.require('SpyConsensusGateway');
const SpyConsensus = artifacts.require('SpyConsensus');
const ProxyTruffleArtifact = require('../../build/contracts/Proxy.json');

const { AccountProvider } = require('../test_lib/utils.js');
const AxiomUtils = require('./utils.js');
const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3');

contract('Axiom::deployMetachainProxies', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let config = {};
  let axiomContract;
  let coreSetupdata;
  let anchorSetupData;
  let consensusGatewaySetupData;
  let consensus;

  beforeEach(async () => {
    config = {
      techGov: accountProvider.get(),
      consensusMasterCopy: await SpyConsensus.new(),
      coreMasterCopy: await SpyCore.new(),
      committeeMasterCopy: accountProvider.get(),
      reputationMasterCopy: accountProvider.get(),
      anchorMasterCopy: await SpyAnchor.new(),
      consensusGatewayMasterCopy: await SpyConsensusGateway.new(),
      txOptions: {
        from: accountProvider.get(),
      },
    };

    axiomContract = await AxiomUtils.deployAxiom(
      config.techGov,
      config.consensusMasterCopy.address,
      config.coreMasterCopy.address,
      config.committeeMasterCopy,
      config.reputationMasterCopy,
      config.anchorMasterCopy.address,
      config.consensusGatewayMasterCopy.address,
      {
        from: accountProvider.get(),
      },
    );
    const newCoreParams = {
      consensus: accountProvider.get(),
      metachainId: Utils.getRandomHash(),
      epochLength: new BN('100'),
      minValidators: new BN('10'),
      joinLimit: new BN('10'),
      reputation: accountProvider.get(),
      height: new BN(Utils.getRandomNumber(1000)),
      parent: Utils.getRandomHash(),
      gasTarget: new BN(Utils.getRandomNumber(999999)),
      dynasty: new BN(Utils.getRandomNumber(10)),
      accumulatedGas: new BN(Utils.getRandomNumber(999999)),
      source: Utils.getRandomHash(),
      sourceBlockHeight: new BN(Utils.getRandomNumber(1000)),
    };

    coreSetupdata = await AxiomUtils.encodeNewCoreParams(newCoreParams);
    anchorSetupData = await AxiomUtils.encodeNewAnchorParams({
      maxStateRoots: new BN('100'),
      consensus: accountProvider.get(),
    });
    consensusGatewaySetupData = await AxiomUtils.encodeNewConsensusGatewayParam();

    consensus = newCoreParams.consensus;
    await axiomContract.setConsensus(newCoreParams.consensus);
  });

  contract('Positive Tests', () => {
    it('should deploy metachain proxies', async () => {
      const returnValues = await axiomContract.deployMetachainProxies.call(
        anchorSetupData,
        coreSetupdata,
        consensusGatewaySetupData,
        { from: consensus },
      );
      const response = await axiomContract.deployMetachainProxies(
        anchorSetupData,
        coreSetupdata,
        consensusGatewaySetupData,
        { from: consensus },
      );

      assert.isOk(
        response.receipt.status,
        'Transaction should success',
      );
      assert.isOk(
        web3.utils.isAddress(returnValues.anchor_),
        'It should return valid anchor address',
      );
      assert.isOk(
        web3.utils.isAddress(returnValues.core_),
        'It should return valid core address',
      );
      assert.isOk(
        web3.utils.isAddress(returnValues.consensusGateway_),
        'It should return valid consensus gateway address',
      );

      assert.strictEqual(
        (await Utils.getCode(returnValues.anchor_)),
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy of Anchor contract byte code must match the compiled binary.',
      );

      assert.strictEqual(
        (await Utils.getCode(returnValues.core_)),
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy of Core contract byte code must match the compiled binary.',
      );

      assert.strictEqual(
        (await Utils.getCode(returnValues.consensusGateway_)),
        ProxyTruffleArtifact.deployedBytecode,
        'Proxy of consensus gateway contract byte code must match the compiled binary.',
      );
    });
  });
});
