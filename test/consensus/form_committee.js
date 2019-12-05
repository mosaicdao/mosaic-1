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
const axiomUtil = require('../axiom/utils.js');

const Consensus = artifacts.require('ConsensusTest');
const SpyAxiom = artifacts.require('SpyAxiom');

contract('Consensus::formCommittee', (accounts) => {
  let consensus;
  let axiom;
  const testInputs = {};
  const accountProvider = new Utils.AccountProvider(accounts);

  beforeEach(async () => {
    consensus = await Consensus.new();
    axiom = await SpyAxiom.new();

    await axiom.setupConsensus(consensus.address);

    // Populate the input data.
    testInputs.committeeSize = new BN(100);
    testInputs.coreAddress = accountProvider.get();
    testInputs.proposal = Utils.getRandomHash();

    await consensus.setCoreLifetime(
      testInputs.coreAddress,
      consensusUtil.CoreLifetime.active,
    );

    await consensus.registerPrecommit(
      testInputs.proposal,
      {
        from: testInputs.coreAddress,
      },
    );
  });
  contract('Negative Tests', async () => {
    it('should fail when pre-commit proposal does not exists for a given core address', async () => {
      const coreAddress = accountProvider.get();

      await Utils.expectRevert(
        consensus.formCommittee(coreAddress),
        'There does not exist a precommitment of the core to a proposal.',
      );
    });

    it('should fail when pre-commit when proposal is 0x for a given core address', async () => {
      await consensus.setPreCommit(testInputs.coreAddress, Utils.ZERO_BYTES32, new BN(10));
      await Utils.expectRevert(
        consensus.formCommittee(testInputs.coreAddress),
        'There does not exist a precommitment of the core to a proposal.',
      );
    });

    it('should fail when current block number is less than committee formation block', async () => {
      const currentBlock = await Utils.getBlockNumber();
      await consensus.setPreCommit(
        testInputs.coreAddress,
        testInputs.proposal,
        currentBlock.addn(consensusUtil.CommitteeFormationDelay),
      );

      await Utils.expectRevert(
        consensus.formCommittee(testInputs.coreAddress),
        'Block height must be higher than set committee formation height.',
      );
    });

    it('should fail when committee formation block is not in most recent 256 blocks', async () => {
      const initialBlockNumber = await Utils.getBlockNumber();
      const committeeFormationDelay = 10;
      const committeeFormationBlockHeight = initialBlockNumber.addn(committeeFormationDelay);
      await consensus.setPreCommit(
        testInputs.coreAddress,
        testInputs.proposal,
        committeeFormationBlockHeight,
      );

      const currentBlock = await Utils.getBlockNumber();
      const advanceBlockNumber = new BN(consensusUtil.BlockSegmentLength)
        .addn(committeeFormationDelay)
        .addn(consensusUtil.CommitteeFormationLength)
        .sub(currentBlock.sub(initialBlockNumber))
        .subn(1);
      // Additional -1 is done because the the block number will be +1 in next step.

      // Advance 256 + committeeFormationBlockHeight blocks.
      await Utils.advanceBlocks(advanceBlockNumber.toNumber(10));

      await Utils.expectRevert(
        consensus.formCommittee(testInputs.coreAddress),
        'Committee formation blocksegment length must be in 256 most recent blocks.',
      );
    });

    it('should fail when committee is already formed', async () => {
      const initialBlockNumber = await Utils.getBlockNumber();
      const committeeFormationBlockHeight = initialBlockNumber
        .addn(consensusUtil.CommitteeFormationDelay);

      await consensus.setPreCommit(
        testInputs.coreAddress,
        testInputs.proposal,
        committeeFormationBlockHeight,
      );

      await Utils.advanceBlocks(consensusUtil.CommitteeFormationDelay);

      await consensus.formCommittee(testInputs.coreAddress);

      await Utils.expectRevert(
        consensus.formCommittee(testInputs.coreAddress),
        'There already exists a committee for the proposal.',
      );
    });
  });

  contract('Positive Tests', () => {
    let committeeFormationBlockHeight;
    beforeEach(async () => {

      // Advance by 256 blocks
      await Utils.advanceBlocks(consensusUtil.BlockSegmentLength);
      const initialBlockNumber = await Utils.getBlockNumber();
      committeeFormationBlockHeight = initialBlockNumber
        .addn(consensusUtil.CommitteeFormationDelay);

      await consensus.setPreCommit(
        testInputs.coreAddress,
        testInputs.proposal,
        committeeFormationBlockHeight,
      );
      // Advance by 7 block
      await Utils.advanceBlocks(consensusUtil.CommitteeFormationDelay);
    });

    it('should form committee when called with correct parameters', async () => {
      await consensus.formCommittee(testInputs.coreAddress);
    });

    it('should update proposals, committee mapping and sentinel committee address', async () => {
      let committeeAddress = await consensus.proposals.call(testInputs.proposal);
      assert.strictEqual(
        committeeAddress,
        Utils.NULL_ADDRESS,
        'Committee address must be null before the committee formation.',
      );

      await consensus.formCommittee(testInputs.coreAddress);

      committeeAddress = await consensus.proposals.call(testInputs.proposal);
      assert.strictEqual(
        Utils.isAddress(committeeAddress) && committeeAddress !== Utils.NULL_ADDRESS,
        true,
        `${committeeAddress} must be a valid non null ethereum address.`,
      );

      const sentinelAddress = await consensus.committees.call(committeeAddress);
      assert.strictEqual(
        sentinelAddress,
        consensusUtil.SentinelCommittee,
        `Sentinel address must be ${sentinelAddress}`,
      );

      const sentinalCommitteeAddress = await consensus
        .committees
        .call(consensusUtil.SentinelCommittee);

      assert.strictEqual(
        sentinalCommitteeAddress,
        committeeAddress,
        `Sentinel committee address must be ${committeeAddress}`,
      );
    });

    it('should verify committee address', async () => {
      let committeeAddress = await consensus.proposals.call(testInputs.proposal);
      assert.strictEqual(
        committeeAddress,
        Utils.NULL_ADDRESS,
        'Committee address must be null before the committee formation.',
      );

      await consensus.formCommittee(testInputs.coreAddress);

      const mockedCommitteeAddress = await axiom.mockedCommitteeAddress.call();
      committeeAddress = await consensus.proposals.call(testInputs.proposal);

      assert.strictEqual(
        committeeAddress,
        mockedCommitteeAddress,
        'Committee address must be equal to the mocked committee address.',
      );
    });

    it('verify spied call data ', async () => {
      await consensus.formCommittee(testInputs.coreAddress);

      // testInputs.committeeSize
      // Get the expected dislocation for the given committee formation height.
      const expectedDislocation = await consensusUtil.getDislocation(committeeFormationBlockHeight);
      // testInputs.proposal
      const expectedCallData = await axiomUtil.encodeNewCommitteeParams({
        consensus: consensus.address,
        committeeSize: testInputs.committeeSize,
        dislocation: expectedDislocation,
        proposal: testInputs.proposal,
      });

      const spyCallData = await axiom.spyNewCommitteeCallData.call();

      assert.strictEqual(
        spyCallData,
        expectedCallData,
        'Call data in spy contract is not correct.',
      );
    });
  });
});
