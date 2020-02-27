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

const MockConsensus = artifacts.require('MockConsensus');
const ConsensusGateway = artifacts.require('ConsensusGateway');

const Web3 = require('web3');
const Utils = require('../test/test_lib/utils.js');

/**
 * Steps to run the script
 *
 * 1. Run geth: docker run -p 8545:8545 -p 8546:8546 -p 30303:30303 mosaicdao/dev-chains:1.0.3 origin
 * 2. Run test: node_modules/.bin/truffle test test/data_generator/deposit_proof.js
 *
 * note: The local web3 instance is used here because docker is exposing 8546 as WebSocket(ws)
 * and to use web3 with http local web3 instace is newly created.
 */
contract('Storage Proof', () => {
  let consensusGateway;
  let setupParam;
  let token;
  let depositor;
  let depositParam;
  let web3;
  let web3Accounts;

  let blockNumber;
  let outboundChannelIdentifier;
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
    web3Accounts = await web3.eth.getAccounts();
    [depositor] = web3Accounts;
    consensusGateway = await ConsensusGateway.new();

    // token = await MockToken.new(18, { from: depositor });
    token = await Utils.deployMockToken(depositor, 200);

    depositParam = {
      amount: '100',
      beneficiary: depositor,
      feeGasPrice: '1',
      feeGasLimit: '1',
    };
    const metachainId = web3.utils.sha3('metachainid');
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
      consensus: consensus.address,
      most: token.address,
      consensusCogateway: '0x1111111111111111111111111111111111111112',
      maxStorageRootItems: new BN(100),
      outboxStorageIndex: new BN(1),
    };

    await consensusGateway.setup(
      setupParam.metachainId,
      setupParam.consensus,
      setupParam.most,
      setupParam.consensusCogateway,
      setupParam.maxStorageRootItems,
      setupParam.outboxStorageIndex,
    );

    outboundChannelIdentifier = await consensusGateway.outboundChannelIdentifier.call();
    await token.approve(
      consensusGateway.address,
      depositParam.amount,
      { from: depositor },
    );
  });

  it('Deposit storage proof for ConsensusGateway:deposit', async () => {
    const messageHash = await consensusGateway.deposit.call(
      depositParam.amount,
      depositParam.beneficiary,
      depositParam.feeGasPrice,
      depositParam.feeGasLimit,
      { from: depositor },
    );

    await consensusGateway.deposit(
      depositParam.amount,
      depositParam.beneficiary,
      depositParam.feeGasPrice,
      depositParam.feeGasLimit,
      { from: depositor },
    );

    blockNumber = (await web3.eth.getBlock('latest')).number;
    const proof = await web3.eth.getProof(
      consensusGateway.address,
      [storagePath('1', [messageHash])],
      blockNumber,
    );

    const accountProof = formatProof(proof.accountProof);
    const storageProof = formatProof(proof.storageProof[0].proof);

    const proofOutput = {
      outboundChannelIdentifier,
      valueToken: setupParam.most,
      messageHash,
      depositParam,
      blockNumber,
      accountProof,
      storageProof,
      metachainId: setupParam.metachainId,
      consensusGateway: consensusGateway.address,
      consensusCogateway: setupParam.consensusCogateway,
      outboxStorageIndex: setupParam.outboxStorageIndex,
      rawProofResult: proof,
    };

    fs.writeFileSync(
      'test/consensus-gateway/data/deposit_proof.json',
      JSON.stringify(proofOutput, null, '    '),
    );
  });
});
