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
const rlp = require('rlp');
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
 * and to use web3 with http local web3 instace is newly created.
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
  let web3;

  function storagePath(
    storageIndex,
    mappings,
  ) {
    let path = '';

    if (mappings && mappings.length > 0) {
      mappings.map((mapping) => {
        path = `${path}${web3.utils.padLeft(mapping, 64)}`;
        return path;
      });
    }

    path = `${path}${web3.utils.padLeft(storageIndex, 64)}`;
    path = web3.utils.sha3(path);

    return path;
  }

  function formatProof(proof) {
    const formattedProof = proof.map(p => rlp.decode(p));
    return `0x${rlp.encode(formattedProof).toString('hex')}`;
  }


  beforeEach(async () => {
    web3 = new Web3('http://localhost:8545');
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
    const proof = await web3.eth.getProof(
      erc20Gateway.address,
      [storagePath('1', [messageHash])],
      blockNumber,
    );

    const accountProof = formatProof(proof.accountProof);
    const storageProof = formatProof(proof.storageProof[0].proof);

    const proofOutput = {
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
      rawProofResult: proof,
    };

    fs.writeFileSync(
      'test/consensus-gateway/data/erc20_deposit_proof.json',
      JSON.stringify(proofOutput, null, '    '),
    );
  });
});
