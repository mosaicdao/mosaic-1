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

const ConsensusGatewayBase = artifacts.require('ConsensusGatewayBase');

const { AccountProvider } = require('../test_lib/utils.js');

contract('ConsensusGatewayBase::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);

  it('should setup consensus gateway base', async () => {
    const most = accountProvider.get();
    const currentMetaBlockHeight = new BN(1);

    const consensusGatewayBase = await ConsensusGatewayBase.new();

    await consensusGatewayBase.setup(
      most,
      currentMetaBlockHeight,
    );

    const mostAddressFromContract = await consensusGatewayBase.most.call();
    const currentMetablockHeightFromContract = await consensusGatewayBase
      .currentMetablockHeight.call();

    assert.strictEqual(
      most,
      mostAddressFromContract,
      'most address must match',
    );

    assert.isOk(
      currentMetaBlockHeight.eq(currentMetablockHeightFromContract),
      `Expected current meta-block height is ${currentMetaBlockHeight.toString(10)}`
      + `but found ${currentMetablockHeightFromContract.toString(10)}`,
    );
  });
});
