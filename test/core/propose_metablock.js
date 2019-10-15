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
const Utils = require('../test_lib/utils.js');

const CoreUtils = require('./utils.js');
const Core = artifacts.require('Core');

let config = {};

async function openCore(
  accountProvider,
  core,
) {
  const minVal = await core.minimumValidatorCount.call();

  for (let i = 0; i < minVal.toNumber(10); i++) {
    let validator = accountProvider.get();
    await config.mockConsensus.joinDuringCreation(validator);
  }
  let coreStatus = await config.core.coreStatus.call();
  assert.isOk(
    CoreUtils.isCoreOpened(coreStatus),
  );
};

contract('Core::proposeMetablock', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  beforeEach(async () => {
    config = {
      chainId: Utils.NULL_ADDRESS,
      epochLength: new BN(100),
      height: new BN(0),
      parent: Utils.ZERO_BYTES32,
      gasTarget: new BN(0),
      dynasty: new BN(0),
      accumulatedGas: new BN(0),
      source: Utils.ZERO_BYTES32,
      sourceBlockHeight: new BN(0),
      deployer: accountProvider.get(),
    };

    config.mockConsensus = await CoreUtils.createConsensusCore(
      config.chainId,
      config.epochLength,
      config.height,
      config.parent,
      config.gasTarget,
      config.dynasty,
      config.accumulatedGas,
      config.source,
      config.sourceBlockHeight,
      {
        from: config.deployer,
      },
    );

    const coreAddress = await config.mockConsensus.core.call();
    config.core = await Core.at(coreAddress);
    Object.freeze(config);

    await openCore(accountProvider, config.core);
  });

  contract('Positive Tests', () => {
    it('should accept proposals', async () => {

    });
  });

});