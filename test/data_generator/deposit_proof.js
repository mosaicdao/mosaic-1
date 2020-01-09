const BN = require('bn.js');
const rlp = require('rlp');
const fs = require('fs');

const MockToken = artifacts.require('MockToken');
const MockConsensus = artifacts.require('MockConsensus');
const ConsensusGateway = artifacts.require('ConsensusGateway');

const Utils = require('../test_lib/utils.js');
const web3 = require('../test_lib/web3');


/**
 * Steps to run the script
 *
 * 1. Run geth: docker run -p 8545:8546 -p 30303:30303 mosaicdao/dev-chains:1.0.3 origin
 * 2. Run test: node_modules/.bin/truffle test test/data_generator/deposit_proof.js
 */
contract('Storage Proof', (accounts) => {
  let consensusGateway;
  let setupParam;
  let token;
  let depositor;
  let depositParam;

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
    accounts = await web3.eth.getAccounts();
    depositor = accounts[0];
    consensusGateway = await ConsensusGateway.new();

    token = await MockToken.new(18, { from: depositor });

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
      JSON.stringify(proofOutput,null, '    '),
    );
  });
});
