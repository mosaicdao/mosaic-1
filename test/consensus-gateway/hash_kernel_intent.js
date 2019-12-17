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

const ConsensusGatewayBase = artifacts.require('ConsensusGatewayBaseTest');

contract('ConsensusGatewayBase::hashKernelIntent', (accounts) => {
  it('should hash kernel content', async () => {
    const consensusGatewayBase = await ConsensusGatewayBase.new();

    const height = new BN(1);
    const kernelHash = '0xb72db4929fec6eb0a73772f5eb48498cceff24c8449d805d5ddbffd87838a9d8';

    const kernelIntentHash = await consensusGatewayBase.hashKernelIntent.call(height, kernelHash);

    const expectedIntentHash = '0x942ad9797599fd9964cee5b758766914683f3b84a483371612861e27eadd125e';
    assert.strictEqual(
      expectedIntentHash,
      kernelIntentHash,
      'Kernel intent hash must match',
    );
  });
});
