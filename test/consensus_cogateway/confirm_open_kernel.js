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

const BN = require('bn.js');
const { AccountProvider } = require('../test_lib/utils.js');
const DeclareOpenKernel = require('../data/declare_open_kernel.json');

const SpyCoconsensus = artifacts.require('SpyCoconsensus');
const ConsensusCogateway = artifacts.require('ConsensusCogatewayDouble');
const SpyAnchor = artifacts.require('SpyAnchor');

contract('CoconsensusGateway::confirmOpenKernel', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  let consensusCogateway;
  const metablockHeight = new BN(2);
  const setupParams = {
    metachainId: DeclareOpenKernel.metachainId,
    utmost: accountProvider.get(),
    consensusGateway: DeclareOpenKernel.address,
    outboxStorageIndex: new BN(1),
    maxStorageRootItems: new BN(100),
    metablockHeight: new BN(2),
  };

  const confirmOpenKernelParams = {
    kernelHeight: metablockHeight.addn(1),
    kernelHash: DeclareOpenKernel.kernelHash,
    feeGasPrice: new BN(10),
    feeGasLimit: new BN(10),
    sender: DeclareOpenKernel.sender,
    blockHeight: DeclareOpenKernel.blockNumber,
    rlpParentNodes: DeclareOpenKernel.serializedStorageProof,
  };

  beforeEach(async () => {
    const spyAnchor = await SpyAnchor.new();
    setupParams.coconsensus = await SpyCoconsensus.new();
    await setupParams.coconsensus.setAnchorAddress(
      setupParams.metachainId,
      spyAnchor.address,
    );

    consensusCogateway = await ConsensusCogateway.new();

    // Set state root.
    await spyAnchor.anchorStateRoot(
      DeclareOpenKernel.blockNumber,
      DeclareOpenKernel.stateRoot,
    );

    await consensusCogateway.setup(
      setupParams.metachainId,
      setupParams.coconsensus.address,
      setupParams.utmost,
      setupParams.consensusGateway,
      setupParams.outboxStorageIndex,
      setupParams.maxStorageRootItems,
      setupParams.metablockHeight,
    );

    await consensusCogateway.setMetablock(metablockHeight);
    await consensusCogateway.setStorageRoot(
      confirmOpenKernelParams.blockHeight,
      DeclareOpenKernel.storageHash,
    );

    await consensusCogateway.setInboundChannelIdentifier(
      DeclareOpenKernel.outboundChannelIdentifier,
    );
  });

  contract('Positive Tests', () => {
    it('should confirm open kernel successfully', async () => {
      const initialNonceForSender = await consensusCogateway.nonces.call(
        confirmOpenKernelParams.sender,
      );

      await consensusCogateway.confirmOpenKernel(
        confirmOpenKernelParams.kernelHeight,
        confirmOpenKernelParams.kernelHash,
        confirmOpenKernelParams.feeGasPrice,
        confirmOpenKernelParams.feeGasLimit,
        confirmOpenKernelParams.sender,
        confirmOpenKernelParams.blockHeight,
        confirmOpenKernelParams.rlpParentNodes,
      );

      const actualKernelHash = await consensusCogateway.kernelHashes.call(
        confirmOpenKernelParams.kernelHeight,
      );
      assert.strictEqual(
        actualKernelHash,
        confirmOpenKernelParams.kernelHash,
        'Invalid kernel hash',
      );

      const actualNonceForSender = await consensusCogateway.nonces.call(
        confirmOpenKernelParams.sender,
      );
      assert.strictEqual(
        initialNonceForSender.addn(1).eq(actualNonceForSender),
        true,
        `Expected nonce for sender is ${initialNonceForSender.addn(1)} but got ${actualNonceForSender}`,
      );

      const actualCurrentMetablockHeight = await consensusCogateway.currentMetablockHeight.call();
      assert.strictEqual(
        confirmOpenKernelParams.kernelHeight.eq(actualCurrentMetablockHeight),
        true,
        `Expected kernel height is ${confirmOpenKernelParams.kernelHeight} but got ${actualCurrentMetablockHeight}`,
      );
    });
  });
});
