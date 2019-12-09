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

const Consensus = artifacts.require('ConsensusTest');

contract('Consensus::hashMetachainId', (accounts) => {
  let consensus;
  let setupParams;
  const accountProvider = new Utils.AccountProvider(accounts);

  beforeEach(async () => {
    consensus = await Consensus.new();
    setupParams = {
      committeeSize: new BN(Utils.getRandomNumber(500)),
      minValidators: new BN(5),
      joinLimit: new BN(7),
      gasTargetDelta: new BN(Utils.getRandomNumber(999999)),
      coinbaseSplitPerMille: new BN(Utils.getRandomNumber(1000)),
      reputation: accountProvider.get(),
      txOptions: {
        from: accountProvider.get(),
      },
    };
    Object.freeze(setupParams);
  });

  contract('Negative Tests', async () => {
    it('should fail when anchor address is 0', async () => {
      await Utils.expectRevert(
        consensus.hashMetachainId(
          Utils.NULL_ADDRESS,
          {
            from: accountProvider.get(),
          },
        ),
        'Anchor address must not be 0.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('verify metachain id typehash', async () => {
      const metachainIdTypehash = await consensus.METACHAIN_ID_TYPEHASH.call();
      const expectedMetachainTypehash = consensusUtil.METACHAIN_ID_TYPEHASH;
      assert.strictEqual(
        metachainIdTypehash,
        expectedMetachainTypehash,
        'Invalid metachain typehash',
      );
    });

    it('verify metachain id', async () => {
      await consensusUtil.setup(consensus, setupParams);

      const mosaicDomainSeparator = await consensus.mosaicDomainSeparator.call();

      assert.isNotNull(
        mosaicDomainSeparator,
        'Mosaic domain separator must not be null',
      );

      assert.notStrictEqual(
        mosaicDomainSeparator,
        Utils.ZERO_BYTES32,
        'Mosaic domain separator must not be 0',
      );

      const anchor = accountProvider.get();
      const metachainIdHash = consensusUtil.getMetachainIdHash(
        anchor,
        consensusUtil.METACHAIN_ID_TYPEHASH,
      );

      const expectedMetachainId = consensusUtil.getMetachainId(
        mosaicDomainSeparator,
        metachainIdHash,
      );
      const metachainIdFromContract = await consensus.hashMetachainId.call(anchor);

      assert.strictEqual(
        metachainIdFromContract,
        expectedMetachainId,
        'Invalid metachain id',
      );
    });
  });
});
