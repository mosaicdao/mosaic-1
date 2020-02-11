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
const utils = require('../../test_lib/utils.js');
const web3 = require('../../test_lib/web3.js');

const { AccountProvider } = require('../../test_lib/utils.js');
const ProveStorageExistence = require('./prove_storage_existence_proof.json');

contract('Proof::proveStorageExistence', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let path;
  let proof;
  let setupParams;

  beforeEach(async () => {
    proof = await Proof.new();

    setupParams = {
      storageAccount: ProveStorageExistence.address,
      stateRootProvider: accountProvider.get(),
      maxStorageRootItems: new BN(100),
    };

    await proof.setupProofExternal(
      setupParams.storageAccount,
      setupParams.stateRootProvider,
      setupParams.maxStorageRootItems,
    );

    await proof.setStorageRootExternal(
      ProveStorageExistence.blockNumber,
      ProveStorageExistence.storageHash,
    );

    path = web3.utils.padLeft(ProveStorageExistence.messageHash,64)
    path = path + web3.utils.padLeft("1",64)
    path = web3.utils.sha3(path);
    path = web3.utils.sha3(path);
  });


  contract('Negative Tests', async () => {
    it('should fail when storage root is zero', async () => {
      const storageRoot = '0x';

      await proof.setStorageRootExternal(
        ProveStorageExistence.blockNumber,
        storageRoot,
      );
      await utils.expectRevert(
        proof.proveStorageExistenceExternal(
          path,
          ProveStorageExistence.value,
          ProveStorageExistence.blockNumber,
          ProveStorageExistence.serializedStorageProof,
        ),
        'Storage root must not be zero',
      );
    });


    it('should fail when a single parameter to proveStorageExistence is wrong/empty', async () => {
      path = '0x';

      await utils.expectRevert(
        proof.proveStorageExistenceExternal(
          path,
          ProveStorageExistence.value,
          ProveStorageExistence.blockNumber,
          ProveStorageExistence.serializedStorageProof,
        ),
        'Merkle proof verification failed.',
      );
    });
  });


  contract('Positive Tests', async () => {
    it('should pass when existence account proof matches', async () => {
      await proof.proveStorageExistenceExternal(
        path,
        ProveStorageExistence.value,
        ProveStorageExistence.blockNumber,
        ProveStorageExistence.serializedStorageProof,
      );
    });
  });
});
