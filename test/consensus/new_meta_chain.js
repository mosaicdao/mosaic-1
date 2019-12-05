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

const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');
const axiomUtil = require('../axiom/utils');

const SpyAxiom = artifacts.require('SpyAxiom');
const Consensus = artifacts.require('Consensus');

contract('Consensus::newMetaChain', (accounts) => {
  const accountProvider = new Utils.AccountProvider(accounts);
  let contracts = {};
  let inputParams = {};

  beforeEach(async () => {
    contracts = {
      SpyAxiom: await SpyAxiom.new(),
      Consensus: await Consensus.new(),
    };

    await contracts.SpyAxiom.setupConsensus(contracts.Consensus.address);

    inputParams = {
      consensus: contracts.Consensus.address,
      chainId: accountProvider.get(),
      epochLength: 100,
      source: Utils.getRandomHash(),
      sourceBlockHeight: 8888,
    };
    Object.freeze(inputParams);
  });

  contract('Negative Tests', async () => {
    it('should fail when caller is not axiom contract address', async () => {
      await Utils.expectRevert(
        contracts.Consensus.newMetaChain(
          inputParams.chainId,
          inputParams.epochLength,
          inputParams.sourceBlockHeight,
          {
            from: accountProvider.get(),
          },
        ),
        'Caller must be axiom address.',
      );
    });

    it('should fail when chain id already exists', async () => {
      await consensusUtil.callNewMetaChainOnConsensus(contracts.SpyAxiom, inputParams);
      await Utils.expectRevert(
        consensusUtil.callNewMetaChainOnConsensus(contracts.SpyAxiom, inputParams),
        'A core is already assigned to this metachain.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should pass when called with correct params', async () => {
      await consensusUtil.callNewMetaChainOnConsensus(contracts.SpyAxiom, inputParams);
    });

    it('should set core address in assignments mapping', async () => {
      await consensusUtil.callNewMetaChainOnConsensus(contracts.SpyAxiom, inputParams);
      const assignedCoreId = await contracts.Consensus.assignments.call(inputParams.chainId);
      const mockedCoreAddress = await contracts.SpyAxiom.mockedCoreAddress.call();
      assert.strictEqual(
        assignedCoreId,
        mockedCoreAddress,
        'Assigned core address must be equal to mocked core address.',
      );
    });

    it('should set chain id in anchors mapping', async () => {
      await consensusUtil.callNewMetaChainOnConsensus(contracts.SpyAxiom, inputParams);
      const anchorAddress = await contracts.Consensus.anchors.call(inputParams.chainId);
      assert.strictEqual(
        anchorAddress,
        inputParams.chainId,
        'Anchor address must be equal to chain id.',
      );
    });

    it('should verify data from spy contract', async () => {
      await consensusUtil.callNewMetaChainOnConsensus(contracts.SpyAxiom, inputParams);
      const newCoreCallData = await contracts.SpyAxiom.spyNewCoreCallData.call();

      /*
        The static values in the below code is based on the SpyAxiom::setupConsensus
        function setupConsensus(Consensus _consensus) public  {
                _consensus.setup(
                    uint256(100),
                    uint256(5),
                    uint256(6),
                    uint256(99999),
                    uint256(200),
                    address(1)
                );
            }
       */
      const expectedCallData = await axiomUtil.encodeNewCoreParams({
        consensus: contracts.Consensus.address,
        chainId: inputParams.chainId,
        epochLength: inputParams.epochLength,
        minValidators: 5,
        joinLimit: 6,
        reputation: '0x0000000000000000000000000000000000000001',
        height: 0,
        parent: Utils.ZERO_BYTES32,
        gasTarget: 99999,
        dynasty: 0,
        accumulatedGas: 0,
        sourceBlockHeight: inputParams.sourceBlockHeight,
      });

      assert.strictEqual(
        newCoreCallData,
        expectedCallData,
        'Call data from spy contract must match the expected data',
      );
    });
  });
});
