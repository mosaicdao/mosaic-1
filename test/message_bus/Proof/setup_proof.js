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

const Proof = artifacts.require('ProofDouble');
const BN = require('bn.js');

const { AccountProvider } = require('../../test_lib/utils.js');

contract('Proof::proveStorageAccount', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let proof;
  let setupParams;

  beforeEach(async () => {
    proof = await Proof.new();

    setupParams = {
      storageAccount: accountProvider.get(),
      stateRootProvider: accountProvider.get(),
      maxStorageRootItems: new BN(100)
    };
  });

  contract('Positive Tests', async () =>{
    it('should do setup successfully', async () => {
      await proof.setupProofTest(
        setupParams.storageAccount,
        setupParams.stateRootProvider,
        setupParams.maxStorageRootItems
      );
      const storageAccount = await proof.storageAccount.call();
      const stateRootProvider = await proof.stateRootProvider.call();

      assert.strictEqual(
        setupParams.storageAccount,
        storageAccount,
        "Storage account address must match with the storage adress provided.",
      );

      assert.strictEqual(
        setupParams.stateRootProvider,
        stateRootProvider,
        "State root provider address must match with the state root adress provided.",
      );
    });
  });
});
