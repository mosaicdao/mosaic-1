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
const EventDecoder = require('../test_lib/event_decoder');

const ConsensusUtils = require('./utils');

const SpyReputation = artifacts.require('SpyReputation');
const Consensus = artifacts.require('ConsensusTest');
const Core = artifacts.require('MockCore');

contract('Consensus::publishEndPoint', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let setupParams = {};
  let consensus;
  let core;
  let coreParams;
  let publishEndpointParams = {};
  const openKernelHeight = new BN('100');
  beforeEach(async () => {
    consensus = await Consensus.new();
    const reputation = await SpyReputation.new();
    core = await Core.new();
    coreParams = {
      beginHeight: openKernelHeight.subn(10),
      endHeight: openKernelHeight.addn(10),
    };
    publishEndpointParams = {
      metachainId: Utils.getRandomHash(),
      service: 'ipfs',
      endpoint: 'endpoint',
      validator: accountProvider.get(),
    };
    setupParams = {
      committeeSize: new BN(Utils.getRandomNumber(500)),
      minValidators: new BN(5),
      joinLimit: new BN(7),
      gasTargetDelta: new BN(Utils.getRandomNumber(999999)),
      coinbaseSplitPerMille: new BN(Utils.getRandomNumber(1000)),
      reputation: reputation.address,
      txOptions: {
        from: accountProvider.get(),
      },
    };

    // setting up of required pre-conditions.
    await reputation.setIsActive(publishEndpointParams.validator, true);

    await core.setOpenkernelHeight(openKernelHeight);
    await core.activateValidator(
      publishEndpointParams.validator,
      coreParams.beginHeight,
      coreParams.endHeight,
    );

    await consensus.setAssignment(
      publishEndpointParams.metachainId,
      core.address,
    );
    await ConsensusUtils.setup(consensus, setupParams);
    Object.freeze(setupParams);
  });

  contract('Positive Tests', () => {
    it('should pass with valid arguments', async () => {
      const tx = await consensus.publishEndpoint(
        publishEndpointParams.metachainId,
        publishEndpointParams.service,
        publishEndpointParams.endpoint,
        {
          from: publishEndpointParams.validator,
        },
      );

      assert.strictEqual(
        tx.receipt.status,
        true,
      );

      // assertion of EndpointPublished event.
      const event = EventDecoder.perform(tx.receipt, consensus.address, Consensus.abi);

      assert.isDefined(
        event.EndpointPublished,
        'Event `EndpointPublished` must be emitted.',
      );

      const eventData = event.EndpointPublished;

      assert.strictEqual(
        eventData._metachainId,
        publishEndpointParams.metachainId,
        'No core exists for the metachain id.',
      );

      assert.strictEqual(
        eventData._core,
        core.address,
        'Invalid core address');

      assert.strictEqual(
        eventData._validator,
        publishEndpointParams.validator,
        'Incorrect validator address',
      );

      assert.strictEqual(
        eventData._service,
        publishEndpointParams.service,
        'Incorrect service address',
      );

      assert.strictEqual(
        eventData._endpoint,
        publishEndpointParams.endpoint,
        'Incorrect service address',
      );
    });
  });

  contract('Negative tests', () => {
    it('should fail when validator is not active', async () => {
      const nonValidator = accountProvider.get();
      await Utils.expectRevert(consensus.publishEndpoint(
        publishEndpointParams.metachainId,
        publishEndpointParams.service,
        publishEndpointParams.endpoint,
        {
          from: nonValidator,
        },
      ),
      'Validator is not active.');
    });
  });
});
