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
const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');
const axiomUtil = require('../axiom/utils');

const SpyAxiom = artifacts.require('SpyAxiom');
const Consensus = artifacts.require('Consensus');

contract('Consensus::newMetachain', (accounts) => {
  const accountProvider = new Utils.AccountProvider(accounts);
  let contracts = {};
  let inputParams = {};

  beforeEach(async () => {
    contracts = {
      SpyAxiom: await SpyAxiom.new(),
      Consensus: await Consensus.new(),
    };

    await contracts.SpyAxiom.setupConsensus(contracts.Consensus.address);

    const anchor = accountProvider.get();

    const mockedAnchorAddress = await contracts.SpyAxiom.mockedAnchorAddress.call();
    const hashedMetachain = await contracts.Consensus.hashMetachainId.call(mockedAnchorAddress);
    inputParams = {
      consensus: contracts.Consensus.address,
      metachainId: hashedMetachain,
      epochLength: 100,
      source: Utils.ZERO_BYTES32,
      sourceBlockHeight: 0,
      anchor,
    };
    Object.freeze(inputParams);
  });

  contract('Negative Tests', async () => {
    it('should fail when caller is not axiom contract address', async () => {
      await Utils.expectRevert(
        contracts.Consensus.newMetachain(
          {
            from: accountProvider.get(),
          },
        ),
        'Caller must be axiom address.',
      );
    });
  });

  contract('Positive Tests', () => {
    it('should pass when called with correct params', async () => {
      await consensusUtil.callNewMetachainOnConsensus(contracts.SpyAxiom, inputParams);
    });

    it('should set core address in assignments mapping', async () => {
      await consensusUtil.callNewMetachainOnConsensus(contracts.SpyAxiom, inputParams);
      const assignedCoreId = await contracts.Consensus.assignments.call(inputParams.metachainId);
      const mockedCoreAddress = await contracts.SpyAxiom.mockedCoreAddress.call();
      assert.strictEqual(
        assignedCoreId,
        mockedCoreAddress,
        'Assigned core address must be equal to mocked core address.',
      );

      const coreLifetimeStatus = new BN(
        await contracts.Consensus.coreLifetimes.call(mockedCoreAddress),
      );

      assert.isOk(
        coreLifetimeStatus.eqn(consensusUtil.CoreLifetime.creation),
        'Corelifetime status must be creation',
      );
    });

    it('should set chain id in anchors mapping', async () => {
      await consensusUtil.callNewMetachainOnConsensus(contracts.SpyAxiom, inputParams);
      const mockedAnchorAddress = await contracts.SpyAxiom.mockedAnchorAddress.call();
      const anchorAddress = await contracts.Consensus.anchors.call(inputParams.metachainId);
      assert.strictEqual(
        anchorAddress,
        mockedAnchorAddress,
        'Anchor address must be equal to expected.',
      );
    });

    it.skip('should verify data from spy contract', async () => {
      await consensusUtil.callNewMetachainOnConsensus(contracts.SpyAxiom, inputParams);
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
      const expectedCoreCallData = await axiomUtil.encodeNewCoreParams({
        consensus: contracts.Consensus.address,
        metachainId: inputParams.metachainId,
        epochLength: new BN(inputParams.epochLength),
        minValidators: new BN(5),
        joinLimit: new BN(6),
        reputation: '0x0000000000000000000000000000000000000001',
        height: new BN(0),
        parent: Utils.ZERO_BYTES32,
        gasTarget: new BN(99999),
        dynasty: new BN(0),
        accumulatedGas: new BN(0),
        sourceBlockHeight: new BN(inputParams.sourceBlockHeight),
      });

      assert.strictEqual(
        newCoreCallData,
        expectedCoreCallData,
        'Core setup call data from spy contract must match the expected data',
      );

      const newConsensusGatewayCallData = await contracts.SpyAxiom
        .spyNewConsensusGatewayCallData.call();

      const expectedConsensusGatewayData = await axiomUtil.encodeNewConsensusGatewayParam();

      assert.strictEqual(
        newConsensusGatewayCallData,
        expectedConsensusGatewayData,
        'Consensus gatway setup call data from spy contract must match the expected data',
      );

      const newAnchorCallData = await contracts.SpyAxiom.spyNewAnchorCallData.call();
      const expectedAnchorCallData = await axiomUtil.encodeNewAnchorParams(
        {
          maxStateRoots: new BN(100),
          consensus: inputParams.consensus,
        },
      );

      assert.strictEqual(
        newAnchorCallData,
        expectedAnchorCallData,
        'Anchor setup call data from spy contract must match the expected data',
      );
    });
  });
});
