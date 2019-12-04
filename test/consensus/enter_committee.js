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

const Consensus = artifacts.require('ConsensusTest');
const Committee = artifacts.require('SpyCommittee');
const Reputation = artifacts.require('SpyReputation');

contract('Consensus::enterCommittee', (accounts) => {
  let consensus;
  let committee;
  let validator;
  let furtherMember;
  let reputation;

  const accountProvider = new Utils.AccountProvider(accounts);

  beforeEach(async () => {
    consensus = await Consensus.new();
    committee = await Committee.new();
    reputation = await Reputation.new();
    validator = await accountProvider.get();
    furtherMember = await accountProvider.get();
  });

  contract('Negative Tests', async () => {
    it('should fail when committee address does not exists in committees mapping', async () => {
      await Utils.expectRevert(
        consensus.enterCommittee(committee.address, validator, furtherMember),
        'Committee does not exist.',
      );
    });

    it('should fail when reputation contract is not set in consensus', async () => {
      await consensus.setCommittee(committee.address, consensusUtil.SentinelCommittee);
      await Utils.expectRevert(
        consensus.enterCommittee(committee.address, validator, furtherMember),
        'revert',
      );
    });

    it('should fail when validator is not active', async () => {
      await consensus.setCommittee(committee.address, consensusUtil.SentinelCommittee);
      await consensus.setReputation(reputation.address);
      await reputation.setIsActive(validator, false);
      await Utils.expectRevert(
        consensus.enterCommittee(committee.address, validator, furtherMember),
        'Validator is not active.',
      );
    });
  });

  contract('Positive Tests', () => {
    beforeEach(async () => {
      await consensus.setCommittee(committee.address, consensusUtil.SentinelCommittee);
      await consensus.setReputation(reputation.address);
      await reputation.setIsActive(validator, true);
    });

    it('should pass when called with correct params', async () => {
      await consensus.enterCommittee(committee.address, validator, furtherMember);
    });

    it('should call enterCommittee function of committee contract', async () => {
      await consensus.enterCommittee(committee.address, validator, furtherMember);
      const isEnterCommitteeFunctionCalled = await committee.isEnterCommitteeFunctionCalled.call();
      assert.strictEqual(
        isEnterCommitteeFunctionCalled,
        true,
        'function enterCommittee of committee contract must be called.',
      );

      const validatorSpyValue = await committee.validator.call();
      assert.strictEqual(
        validatorSpyValue,
        validator,
        'Validator spy address must equal to validator address provided '
        + 'while calling enterCommittee function.',
      );

      const furtherMemberSpyValue = await committee.furtherMember.call();
      assert.strictEqual(
        furtherMemberSpyValue,
        furtherMember,
        'furtherMember spy address must equal to furtherMember address provided'
        + ' while calling enterCommittee function.',
      );
    });
  });
});
