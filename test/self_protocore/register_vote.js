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
const ProtocoreUtils = require('../protocore/utils');
const Utils = require('../test_lib/utils.js');

const SelfProtocore = artifacts.require('TestSelfProtocore');

const config = {};

contract('SelfProtocore::registerVote', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config.voteMessageHash = Utils.getRandomHash();
    config.epochLength = new BN(100);

    config.selfProtocore = await SelfProtocore.new();
    config.v = await ProtocoreUtils.Validator.create();
    config.sig = await config.v.ecsign(Utils.getRandomHash());

  });

  contract('Negative Tests', async () =>{
    it('should revert if current block number is greater than target block '
    +'number and epoch length.', async () => {
      let block = await Utils.getBlockNumber();
      const targetBlockNumber = block.add(config.epochLength);

      await config.selfProtocore.setLink(
        config.voteMessageHash,
        targetBlockNumber,
        config.epochLength,
      );

      await Utils.advanceBlocks(config.epochLength.muln(2));

      await Utils.expectRevert(
        config.selfProtocore.registerVote(
          config.voteMessageHash,
          config.sig.r,
          config.sig.s,
          config.sig.v,
        ),
        'Current block number should be less than the sum of the target '
        +'block number and epoch length',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('should successfully register vote for given vote message hash', async () =>{
      let block = await Utils.getBlockNumber();
      const targetBlockNumber = block.add(config.epochLength);

      await config.selfProtocore.setLink(
        config.voteMessageHash,
        targetBlockNumber,
        config.epochLength,
      );

      await config.selfProtocore.registerVote(
        config.voteMessageHash,
        config.sig.r,
        config.sig.s,
        config.sig.v,
      );
    });
  });
});
