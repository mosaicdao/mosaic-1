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

const { AccountProvider } = require('../test_lib/utils.js');
const AxiomUtils = require('./utils.js');
const web3 = require('../test_lib/web3');

contract('Axiom::deployMetachainProxies', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let config = {};
  let axiomContract;
  let anchorSetupData;
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

    anchorSetupData = await AxiomUtils.encodeNewAnchorParams({
      maxStateRoots: new BN('100'),
      consensus: accountProvider.get(),
    });

    consensus = accountProvider.get();
    await axiomContract.setConsensus(consensus);
  });

  contract('Positive Tests', () => {
    it('should deploy anchor proxy', async () => {
      const anchorAddress = await axiomContract.deployAnchor.call(
        anchorSetupData,
        { from: consensus },
      );
      const response = await axiomContract.deployAnchor(
        anchorSetupData,
        { from: consensus },
      );

      assert.isOk(
        response.receipt.status,
        'Transaction should success',
      );

      assert.isOk(
        web3.utils.isAddress(anchorAddress),
        'It should return valid anchor address',
      );
    });
  });
});
