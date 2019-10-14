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

async function assertValidatorHeight(
  core,
  validator,
  expBeginHeight,
  expEndHeight,
) {
  const beginHeight = await core.validatorBeginHeight(validator);
  const endHeight = await core.validatorEndHeight(validator);

  assert.isOk(
    beginHeight.eq(expBeginHeight),
  );
  
  assert.isOk(
    endHeight.eq(expEndHeight),
  );
}

contract('Core::joinDuringCreation', (accounts) => {
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
  });

  contract('Positive Tests', () => {
    it('should add one validator', async () => {
      const validator = accountProvider.get();

      const MaxFutureEndHeight = await config.core.MAX_FUTURE_END_HEIGHT.call();
      const coreStatus0 = await config.core.coreStatus.call();
      assert.isOk(
        CoreUtils.isCoreCreated(coreStatus0),
      );

      await config.mockConsensus.joinDuringCreation(validator);
      await assertValidatorHeight(
        config.core,
        validator,
        config.height,
        MaxFutureEndHeight,
      )
      const coreStatus = await config.core.coreStatus.call();
      assert.isOk(
        CoreUtils.isCoreCreated(coreStatus),
      );
    });

    it('should open after enough validators join', async () => {
      const validator2 = accountProvider.get();
      const minVal = await config.core.minimumValidatorCount.call();
      const joinLim = await config.core.joinLimit.call();
      console.log(minVal);
      console.log(joinLim);
    });
  });
});