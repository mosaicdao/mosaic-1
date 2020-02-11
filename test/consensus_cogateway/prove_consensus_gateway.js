// Copyright 2020 OpenST Ltd.
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

const BN = require('bn.js');
const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');
const ProveConsensusGatewayProof = require('../data/prove_consensus_gateway_proof.json');

const SpyCoconsensus = artifacts.require('SpyCoconsensus');
const ConsensusCogateway = artifacts.require('ConsensusCogatewayDouble');
const SpyAnchor = artifacts.require('SpyAnchor');

contract('CoConsensusgateway::proveConsensusGateway', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  let consensusCogateway;

  const setupParams = {
    metachainId: Utils.getRandomHash(),
    utMOST: accountProvider.get(),
    consensusGateway: accountProvider.get(),
    outboxStorageIndex: new BN(1),
    maxStorageRootItems: new BN(100),
    metablockHeight: new BN(2),
  };

  beforeEach(async () => {
    const spyAnchor = await SpyAnchor.new();
    setupParams.coConsensus = await SpyCoconsensus.new();
    await setupParams.coConsensus.setAnchorAddress(
      setupParams.metachainId,
      spyAnchor.address,
    );

    consensusCogateway = await ConsensusCogateway.new();

    // Set stateroot.
    await spyAnchor.anchorStateRoot(
      ProveConsensusGatewayProof.blockNumber,
      ProveConsensusGatewayProof.stateRoot,
    );

    await consensusCogateway.setup(
      setupParams.metachainId,
      setupParams.coConsensus.address,
      setupParams.utMOST,
      ProveConsensusGatewayProof.address,
      setupParams.outboxStorageIndex,
      setupParams.maxStorageRootItems,
      setupParams.metablockHeight,
    );
  });

  contract('Positive Tests', () => {
    it('should prove successfully', async () => {
      await consensusCogateway.proveConsensusGateway(
        ProveConsensusGatewayProof.blockNumber,
        ProveConsensusGatewayProof.rlpAccountNode,
        ProveConsensusGatewayProof.rlpParentNodes,
      );

      const actualStorageHash = await consensusCogateway.storageRoots.call(
        ProveConsensusGatewayProof.blockNumber,
      );

      assert.strictEqual(
        actualStorageHash,
        ProveConsensusGatewayProof.storageHash,
        'Incorrect storage hash',
      );
    });
  });
});
