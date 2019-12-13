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

const MockCore = artifacts.require('MockCore');

contract('Core::getOpenKernel', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let core;
  const kernelData = {
    openKernelHeight: new BN(100),
    openKernelHash: Utils.getRandomHash(),
  };

  beforeEach(async () => {
    core = await MockCore.new();

    await core.setOpenkernelHeight(kernelData.openKernelHeight, { from: accountProvider.get() });
    await core.setOpenKernelHash(kernelData.openKernelHash, { from: accountProvider.get() });
  });

  contract('Positive Tests', async () => {
    it('should return openkernelhash and openkernelheight ', async () => {
      const actualKernelData = await core.getOpenKernel.call();

      assert.strictEqual(
        actualKernelData.openKernelHash_,
        kernelData.openKernelHash,
        'Invalid openkernelhash',
      );
      assert.strictEqual(
        kernelData.openKernelHeight.eq(actualKernelData.openKernelHeight_),
        true,
        `Expected open kernel height value is ${kernelData.openKernelHeight} but got `
         + `${actualKernelData.openKernelHeight_}`,
      );
    });
  });
});
