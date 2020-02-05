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
const web3 = require('../../test_lib/web3.js');

const { AccountProvider } = require('../../test_lib/utils.js');
const ProveStorageExistence = require('./prove_storage_existence_proof.json');

contract('Proof::proveStorageExistence', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let proof;
  let setupParams;
  let actualPath;
  let expectedPath;
  let path;

  beforeEach(async () => {
    proof = await Proof.new();

    setupParams = {
      storageAccount: ProveStorageExistence.address,
      stateRootProvider: accountProvider.get(),
      maxStorageRootItems: new BN(100),
    };

    await proof.setupProofDouble(
      setupParams.storageAccount,
      setupParams.stateRootProvider,
      setupParams.maxStorageRootItems,
    );
  });

  it('should pass when actual storage path matches with expected storage path', async () => {
    actualPath = await proof.storagePathDouble(
      new BN(1),
      ProveStorageExistence.messageHash,
    );

    path = web3.utils.padLeft(ProveStorageExistence.messageHash, 64);
    path += web3.utils.padLeft('1', 64);
    const storagePath = web3.utils.sha3(path);
    expectedPath = web3.utils.sha3(storagePath);

    assert.strictEqual(
      expectedPath,
      actualPath,
      `Storage path should be ${actualPath} but found ${expectedPath}`,
    );
  });
});
