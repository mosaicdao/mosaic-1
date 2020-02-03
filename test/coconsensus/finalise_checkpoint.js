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

'use strict';

const BN = require('bn.js');

const { AccountProvider } = require('../test_lib/utils.js');
const Utils = require('../test_lib/utils.js');

const CoconsensusUtils = require('./utils');

contract('Coconsensus::finaliseCheckpoint', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  const config = {};

  beforeEach(async () => {
    const { deployCoconsensus } = CoconsensusUtils;
    Object.assign(config, await deployCoconsensus(accountProvider));

    const { selfProtocore } = config.contracts;
    const lastFinalizedBlock = await selfProtocore.latestFinalizedCheckpoint();
    const epochLength = await selfProtocore.epochLength();

    // Input params.
    config.params = {};
    config.params.metachainId = await selfProtocore.metachainId();
    config.params.finalisationBlockNumber = epochLength.add(lastFinalizedBlock.blockNumber_);
    config.params.finalisationBlockhash = Utils.getRandomHash();
    config.params.expectedDynasty = new BN(4);

    // Set the dynsaty number for testing purpose.
    await selfProtocore.setDynasty(config.params.expectedDynasty);
  });

  contract('Negative Tests', async () => {
    it('should revert when not called by protocore address', async () => {
      const { coconsensus } = config.contracts;
      await Utils.expectRevert(
        coconsensus.finaliseCheckpoint(
          config.params.metachainId,
          config.params.finalisationBlockNumber,
          config.params.finalisationBlockhash,
        ),
        'Only protocore contract can call this function.',
      );
    });

    it('should revert when called more than once with same params', async () => {
      const { selfProtocore } = config.contracts;
      /*
       * The msg.sender for Coconsensus::finaliseCheckpoint must be the
       * protocore contract address. So for the testing purpose call
       * `testFinaliseCheckpoint` function which will internally call the
       * Coconsensus::finaliseCheckpoint.
       */
      await selfProtocore.testFinaliseCheckpoint(
        config.params.metachainId,
        config.params.finalisationBlockNumber,
        config.params.finalisationBlockhash,
      );
      await Utils.expectRevert(
        selfProtocore.testFinaliseCheckpoint(
          config.params.metachainId,
          config.params.finalisationBlockNumber,
          config.params.finalisationBlockhash,
        ),
        'The block number of the checkpoint must be greater than the block '
        + 'number of last finalised checkpoint.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should finalize the checkpoint', async () => {
      const { selfProtocore, coconsensus } = config.contracts;
      /*
       * The msg.sender for Coconsensus::finaliseCheckpoint must be the
       * protocore contract address. So for the testing purpose call
       * `testFinaliseCheckpoint` function which will internally call the
       * Coconsensus::finaliseCheckpoint.
       */
      await selfProtocore.testFinaliseCheckpoint(
        config.params.metachainId,
        config.params.finalisationBlockNumber,
        config.params.finalisationBlockhash,
      );

      // Assert if the value is set in the blockTip mapping of coconsensus contract.
      const blockTip = await coconsensus.blockTips(config.params.metachainId);
      assert.strictEqual(
        blockTip.eq(config.params.finalisationBlockNumber),
        true,
        `The block tip in contract ${blockTip.toString(10)} must be equal to `
        + `expected block number ${config.params.finalisationBlockNumber.toString(10)}`,
      );

      // Assert if the value is set in the blockchain mapping of coconsensus contract.
      const blockchain = await coconsensus.blockchains(
        config.params.metachainId,
        config.params.finalisationBlockNumber,
      );
      assert.strictEqual(
        blockchain.blockHash,
        config.params.finalisationBlockhash,
        'The proposed block hash must be set in the blockchains mapping.',
      );
      assert.strictEqual(
        blockchain.commitStatus.eqn(2),
        true,
        'The commit status in the blockchain mapping must be Finalized.',
      );
      assert.strictEqual(
        blockchain.statusDynasty.eq(config.params.expectedDynasty),
        true,
        'The status dynasty in the blockchain must be '
        + ` ${config.params.expectedDynasty.toString(10)}`,
      );
    });
  });
});
