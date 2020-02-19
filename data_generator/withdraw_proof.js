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
const Web3 = require('web3');

const MockConsensus = artifacts.require('MockConsensus');
const ConsensusCogateway = artifacts.require('ConsensusCogateway');
const Utils = require('../test/test_lib/utils.js');

/**
 * Instructions to generate proof
 * use web3 version as 1.0.0-beta.53
 * 1. run geth : docker run -p 8545:8545 -p 8546:8546 -p 30303:30303 mosaicdao/dev-chains:1.0.3 origin
 * 2. run test : truffle test data_generator/withdraw_proof.js
 */
contract('Withdraw Proof', (accounts) => {
  let consensusCogateway;
  let setupParam;
  let token;
  let withdrawer;
  let withdrawParam;
  let web3;
  let blockNumber;
  let outboundChannelIdentifier;
  let metachainId;
​
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
    web3 = new Web3("http://localhost:8545");
    accounts = await web3.eth.getAccounts();
    withdrawer = accounts[0];

    token = await Utils.deployMockToken(withdrawer,200);
    consensusCogateway = await ConsensusCogateway.new();

    withdrawParam = {
      amount: '10',
      beneficiary: withdrawer,
      feeGasPrice: '1',
      feeGasLimit: '1',
    };

    metachainId = Utils.getRandomHash();

    const consensusConfig = {
      metachainId,
      epochLength: '100',
      minValidatorCount: '5',
      validatorJoinLimit: '20',
      height: '0',
      parent: Utils.ZERO_BYTES32,
      gasTarget: '10',
      dynasty: '0',
      accumulatedGas: '1',
      sourceBlockHeight: '0',
    };

    const consensus = await MockConsensus.new(
      consensusConfig.metachainId,
      consensusConfig.epochLength,
      consensusConfig.minValidatorCount,
      consensusConfig.validatorJoinLimit,
      consensusConfig.height,
      consensusConfig.parent,
      consensusConfig.gasTarget,
      consensusConfig.dynasty,
      consensusConfig.accumulatedGas,
      consensusConfig.sourceBlockHeight,
    );

    setupParam = {
      metachainId,
      utmost: token.address,
      consensusGateway: '0x1111111111111111111111111111111111111112',
      maxStorageRootItems: new BN(100),
      outboxStorageIndex: new BN(1),
      metablockHeight: new BN(1),
    };

    await consensusCogateway.setup(
      setupParam.metachainId,
      consensus.address,
      setupParam.utmost,
      setupParam.consensusGateway,
      setupParam.maxStorageRootItems,
      setupParam.outboxStorageIndex,
      setupParam.metablockHeight,
    );

    outboundChannelIdentifier = await consensusCogateway.outboundChannelIdentifier.call();
​
    await token.approve(consensusCogateway.address, withdrawParam.amount, {
      from: withdrawer,
    });
  });
​
  it('Withdraw storage proof for ConsensusCogateway:withdraw', async () => {
    const messageHash = await consensusCogateway.withdraw.call(
      withdrawParam.amount,
      withdrawParam.beneficiary,
      withdrawParam.feeGasPrice,
      withdrawParam.feeGasLimit,
      { from: withdrawer },
    );
​
    await consensusCogateway.withdraw(
      withdrawParam.amount,
      withdrawParam.beneficiary,
      withdrawParam.feeGasPrice,
      withdrawParam.feeGasLimit,
      { from: withdrawer },
    );
​
    blockNumber = (await web3.eth.getBlock('latest')).number;
    const proof = await web3.eth.getProof(
      consensusCogateway.address,
      [storagePath('1', [messageHash])],
      blockNumber,
    );
​
    const accountProof = formatProof(proof.accountProof);
    const storageProof = formatProof(proof.storageProof[0].proof);
​
    const proofOutput = {
      outboundChannelIdentifier,
      messageHash,
      withdrawParam,
      blockNumber,
      accountProof,
      storageProof,
      metachainId: metachainId,
      consensusGateway: setupParam.consensusGateway,
      consensusCogateway: consensusCogateway.address,
      outboxStorageIndex: setupParam.outboxStorageIndex,
      rawProofResult: proof,
    };

    fs.writeFileSync(
      'test/consensus-gateway/data/withdraw_proof.json',
      JSON.stringify(proofOutput,null, '    '),
    );
  });
});
