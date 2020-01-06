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

const BN = require('../../node_modules/bn.js/lib/bn');
const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
// const ConsensusGatewayUtils = require('./utils');
const ProveConsensusGatewayProof = require('./prove_consensus_gateway_proof.json');

// const SpyCoConsensus = artifacts.require('SpyCoConsensus');
const ConsensusCoGateway = artifacts.require('MockConsensusCoGateway');
const SpyStateRootProvider = artifacts.require('SpyStateRootProvider');

contract('CoConsensusGateway::proveConsensusGateway', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  let consensusCoGateway;
  // const anchor = accountProvider.get();
  const setupParams = {
    metachainId: Utils.getRandomHash(),
    utMOST: accountProvider.get(),
    coConsensus: accountProvider.get(),
    consensusGateway: accountProvider.get(),
    outboxStorageIndex: new BN(1),
    maxStorageRootItems: new BN(100),
    metablockHeight: new BN(2),
  };

  beforeEach(async () => {
    const stateRootProvider = await SpyStateRootProvider.new();
    // setupParams.coConsensus = await SpyCoConsensus.new();
    consensusCoGateway = await ConsensusCoGateway.new();
    await consensusCoGateway.setupInitialData(
      ProveConsensusGatewayProof.address,
      stateRootProvider.address,
      '100',
    );
    // await setupParams.coConsensus.setAnchorAddress(setupParams.metachainId, anchor);

    // set stateroot
    await stateRootProvider.setStateRoot(
      ProveConsensusGatewayProof.stateRoot,
      ProveConsensusGatewayProof.blockNumber,
    );
    // bytes32 _metachainId,
    //         address _coConsensus,
    //         ERC20I _utMOST,
    //         address _consensusGateway,
    //         uint8 _outboxStorageIndex,
    //         uint256 _maxStorageRootItems,
    //         uint256 _metablockHeight
    // await consensusCoGateway.setup(
    //   setupParams.metachainId,
    //   setupParams.coConsensus,
    //   setupParams.utMOST,
    //   setupParams.consensusGateway,
    //   setupParams.outboxStorageIndex,
    //   setupParams.maxStorageRootItems,
    //   setupParams.metablockHeight,
    // );
  });

  contract('Positive Tests', () => {
    it('should prove successfully', async () => {
      await consensusCoGateway.proveConsensusGateway(
        ProveConsensusGatewayProof.blockNumber,
        ProveConsensusGatewayProof.rlpAccountNode,
        ProveConsensusGatewayProof.rlpParentNodes,
      );
    });
  });
});
