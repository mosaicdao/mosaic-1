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

const SpyConsensus = artifacts.require('SpyConsensus');
const SpyReputation = artifacts.require('SpyReputation');
const SpyAnchor = artifacts.require('SpyAnchor');
const SpyConsensusGateway = artifacts.require('SpyConsensusGateway');

let config = {};
let contracts = {};
let constructionParams = {};
let newMetachainParams = {};
let axiom;

contract('Axiom::newMetachain', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    contracts = {
      SpyConsensus: await SpyConsensus.new(),
      SpyReputation: await SpyReputation.new(),
      SpyAnchor: await SpyAnchor.new(),
      SpyConsensusGateway: await SpyConsensusGateway.new(),
    };

    constructionParams = {
      techGov: accountProvider.get(),
      consensusMasterCopy: contracts.SpyConsensus.address,
      coreMasterCopy: accountProvider.get(),
      committeeMasterCopy: accountProvider.get(),
      reputationMasterCopy: contracts.SpyReputation.address,
      anchorMasterCopy: contracts.SpyAnchor.address,
      consensusGatewayMasterCopy: contracts.SpyConsensusGateway.address,
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
      most: accountProvider.get(),
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

    newMetachainParams = {
      txOptions: {
        from: constructionParams.techGov,
      },
    };
  });

  contract('Negative Tests', () => {
    it('should fail when called by non technical governance address', async () => {
      newMetachainParams.txOptions.from = accountProvider.get();
      await Utils.expectRevert(
        AxiomUtils.newMetachainWithConfig(axiom, newMetachainParams),
        'Caller must be technical governance address.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should pass when called with correct params', async () => {
      await AxiomUtils.newMetachainWithConfig(axiom, newMetachainParams);
    });


    it('should validate the spied values of the consensus proxy contract', async () => {
      const response = await AxiomUtils.newMetachainWithConfig(axiom, newMetachainParams);

      assert.isOk(
        response.receipt.logs.length > 0,
        'Must emit event',
      );
      const eventObject = response.receipt.logs[0];

      assert.strictEqual(
        eventObject.event,
        'MetachainCreated',
        'Must emit MetachainCreated event',
      );

      assert.strictEqual(
        eventObject.args.metachainId,
        web3.utils.sha3('1'),
        'Must emit correct metachain Id',
      );
    });
  });
});
