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

const BN = require('bn.js');
const fs = require('fs');

const ERC20Gateway = artifacts.require('ERC20Gateway');

const Web3 = require('web3');
const { AccountProvider } = require('../../test/test_lib/utils');
const Utils = require('../../test/test_lib/utils');

/**
 * Steps to run the script
 *
 * 1. Run geth: docker run -p 8545:8545 -p 8546:8546 -p 30303:30303 mosaicdao/dev-chains:1.0.3 origin
 * 2. Run test: node_modules/.bin/truffle test data_generator/erc20-gateways/deposit_proof.js
 *
 * note: The local web3 instance is used here because docker is exposing 8546 as WebSocket(ws)
 * and to use web3 with http local web3 instance is newly created.
 */
contract('ERC20Gateway::deposit', async (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let erc20Gateway;
  let erc20Cogateway;
  let stateRootProvider;
  let setupParam;
  let valueToken;
  let depositor;
  let param;
  let outboundChannelIdentifier;
  let blockNumber;
  const web3 = new Web3('http://localhost:8545');

  beforeEach(async () => {
    erc20Gateway = await ERC20Gateway.new();
    erc20Cogateway = accountProvider.get();
    stateRootProvider = accountProvider.get();

    depositor = accountProvider.get();
    valueToken = await Utils.deployMockToken(depositor, 200);

    param = {
      amount: '100',
      beneficiary: accountProvider.get(),
      feeGasPrice: '1',
      feeGasLimit: '1',
      valueToken: valueToken.address,
    };
    setupParam = {
      metachainId: Utils.getRandomHash(),
      erc20Cogateway,
      stateRootProvider,
      maxStorageRootItems: new BN(50),
      coGatewayOutboxIndex: new BN(6),
    };
    await erc20Gateway.setup(
      setupParam.metachainId,
      setupParam.erc20Cogateway,
      setupParam.stateRootProvider,
      setupParam.maxStorageRootItems,
      setupParam.coGatewayOutboxIndex,
    );

    outboundChannelIdentifier = await erc20Gateway.outboundChannelIdentifier.call();
    await valueToken.approve(
      erc20Gateway.address,
      param.amount,
      { from: depositor },
    );
  });

  it('Deposit storage proof for ERC20Gateway:deposit', async () => {
    const messageHash = await erc20Gateway.deposit.call(
      param.amount,
      param.beneficiary,
      param.feeGasPrice,
      param.feeGasLimit,
      param.valueToken,
      { from: depositor },
    );

    await erc20Gateway.deposit(
      param.amount,
      param.beneficiary,
      param.feeGasPrice,
      param.feeGasLimit,
      param.valueToken,
      { from: depositor },
    );

    blockNumber = (await web3.eth.getBlock('latest')).number;
    const outboxOffset = await erc20Gateway.OUTBOX_OFFSET.call();

    const proof = await web3.eth.getProof(
      erc20Gateway.address,
      [Utils.storagePath(outboxOffset, [messageHash])],
      blockNumber,
    );

    const accountProof = Utils.formatProof(proof.accountProof);
    const storageProof = Utils.formatProof(proof.storageProof[0].proof);

    const proofOutput = {
      address: depositor,
      outboundChannelIdentifier,
      valueToken: param.valueToken,
      messageHash,
      param,
      blockNumber,
      accountProof,
      storageProof,
      metachainId: setupParam.metachainId,
      erc20Gateway: erc20Gateway.address,
      erc20Cogateway: erc20Cogateway.address,
      outboxStorageIndex: setupParam.outboxStorageIndex,
      stateRootProvider,
      rawProofResult: proof,
    };

    fs.writeFileSync(
      'test/erc20_gateway/data/erc20_deposit_proof.json',
      JSON.stringify(proofOutput, null, '    '),
    );
  });
});
