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
const SpyAnchor = artifacts.require('SpyAnchor');

const utils = require('../../test_lib/utils.js');
const web3 = require('../../test_lib/web3.js');

const BN = require('bn.js');
const { AccountProvider } = require('../../test_lib/utils.js');
const ProveStorageAccount = require('./prove_storage_account_proof.json');

contract('Proof:proveStorageAccount', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let proof;
  let spyAnchor;
  let setupParams;
  let consensus;
  let ExpectedStorageRoot;
  let CalculatedStorageRoot;

  beforeEach(async () => {
    proof = await Proof.new();
    spyAnchor = await SpyAnchor.new();

    setupParams = {
      storageAccount: ProveStorageAccount.address,
      stateRootProvider: spyAnchor.address,
      maxStorageRootItems: new BN(100)
    };

    await proof.setupProofDouble(
      setupParams.storageAccount,
      setupParams.stateRootProvider,
      setupParams.maxStorageRootItems
    );

    // spyAnchor setup
    consensus = accountProvider.get();
    await spyAnchor.setup(
      setupParams.maxStorageRootItems,
      consensus
    );

    // setting anchor state root in spyAnchor
    await spyAnchor.anchorStateRoot(
      ProveStorageAccount.blockNumber,
      ProveStorageAccount.stateRoot
    );

    console.log('Actual state root :-' + ProveStorageAccount.stateRoot);
    console.log('State root from spyAnchor :-' + await spyAnchor.spyStateRoot.call());
    console.log('BlockHeight from spyAnchor :-', await spyAnchor.spyBlockHeight.call());
  });

  contract('Positive Tests', async () => {
    it('should pass when account storage root proof matches', async() => {
      await proof.proveStorageAccountDouble(
        new BN(ProveStorageAccount.blockNumber),
        ProveStorageAccount.rlpAccountNode,
        ProveStorageAccount.rlpParentNodes
      );

      ExpectedStorageRoot = await proof.storageRoots.call(ProveStorageAccount.blockNumber);
      console.log('Storage root :-', ExpectedStorageRoot);

      CalculatedStorageRoot = ProveStorageAccount.storageHash;

      assert.strictEqual(
        ExpectedStorageRoot,
        CalculatedStorageRoot,
        "Storage root/hash generated must match with storage root calculated.",
      );
    });
  });
});
