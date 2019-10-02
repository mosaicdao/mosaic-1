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
const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');
const consensusUtil = require('./utils.js');

const Consensus = artifacts.require('ConsensusTest');
const CommitteeTruffleArtifact = require('../../build/contracts/Committee.json');
const Committee = artifacts.require('Committee');

contract('Consensus::formCommittee', (accounts) => {
  let consensus;
  const testInputs = {};
  const accountProvider = new Utils.AccountProvider(accounts);

  beforeEach(async () => {
    // Populate the input data.
    testInputs.committeeSize = new BN(10);
    testInputs.coreAddress = accountProvider.get();
    testInputs.proposal = web3.utils.sha3('PROPOSAL_1');
    consensus = await Consensus.new(testInputs.committeeSize);

    await consensus.setCoreStatus(
      testInputs.coreAddress,
      consensusUtil.CORE_STATUS_ACTIVE,
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

    it('should fail when pre-commit committee formation block height is zero for a given core address', async () => {
      await consensus.setPreCommit(testInputs.coreAddress, testInputs.proposal, new BN(0));
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
        currentBlock.add(consensusUtil.COMMITTEE_FORMATION_DELAY),
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
      const advanceBlockNumber = consensusUtil.BLOCK_SEGMENT_LENGTH
        .addn(committeeFormationDelay)
        .add(consensusUtil.COMMITTEE_FORMATION_LENGTH)
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
        .add(consensusUtil.COMMITTEE_FORMATION_DELAY);

      await consensus.setPreCommit(
        testInputs.coreAddress,
        testInputs.proposal,
        committeeFormationBlockHeight,
      );

      await Utils.advanceBlocks(consensusUtil.COMMITTEE_FORMATION_DELAY.toNumber(10));

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
      const initialBlockNumber = await Utils.getBlockNumber();
      committeeFormationBlockHeight = initialBlockNumber
        .add(consensusUtil.COMMITTEE_FORMATION_DELAY);

      await consensus.setPreCommit(
        testInputs.coreAddress,
        testInputs.proposal,
        committeeFormationBlockHeight,
      );
      await Utils.advanceBlocks(consensusUtil.COMMITTEE_FORMATION_DELAY.toNumber(10));
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
        web3.utils.isAddress(committeeAddress) && committeeAddress !== Utils.NULL_ADDRESS,
        true,
        `${committeeAddress} must be a valid non null ethereum address.`,
      );

      const sentinelAddress = await consensus.committees.call(committeeAddress);
      assert.strictEqual(
        sentinelAddress,
        consensusUtil.SENTINEL_COMMITTEES,
        `Sentinel address must be ${sentinelAddress}`,
      );

      const sentinalCommitteeAddress = await consensus
        .committees
        .call(consensusUtil.SENTINEL_COMMITTEES);

      assert.strictEqual(
        sentinalCommitteeAddress,
        committeeAddress,
        `Sentinel committee address must be ${committeeAddress}`,
      );
    });

    it('should verify if the committee contract is deployed on committee formation', async () => {
      let committeeAddress = await consensus.proposals.call(testInputs.proposal);
      assert.strictEqual(
        committeeAddress,
        Utils.NULL_ADDRESS,
        'Committee address must be null before the committee formation.',
      );

      await consensus.formCommittee(testInputs.coreAddress);

      committeeAddress = await consensus.proposals.call(testInputs.proposal);

      const committeeContractByteCode = await web3.eth.getCode(committeeAddress);

      assert.strictEqual(
        committeeContractByteCode,
        CommitteeTruffleArtifact.deployedBytecode,
        'Committee contract byte code must match the compiled binary.',
      );
    });

    it('verify dislocation, committeSize and proposal params of new formed committee', async () => {
      await consensus.formCommittee(testInputs.coreAddress);

      // Get the expected dislocation for the given committee formation height.
      const expectedDislocation = await consensusUtil.getDislocation(committeeFormationBlockHeight);

      const committeeAddress = await consensus.proposals.call(testInputs.proposal);
      const committee = await Committee.at(committeeAddress);

      const dislocation = await committee.dislocation.call();
      assert.strictEqual(
        dislocation,
        expectedDislocation,
        'dislocation is incorrect while forming committee',
      );

      const proposal = await committee.proposal.call();
      assert.strictEqual(
        proposal,
        testInputs.proposal,
        'Proposal is incorrect while forming committee',
      );

      const committeeSize = await committee.committeeSize.call();
      assert.strictEqual(
        committeeSize.eq(testInputs.committeeSize),
        true,
        `Committee size from the contract ${committeeSize} must be equal `
        + `to ${testInputs.committeeSize} while forming committee`,
      );
    });
  });
});
