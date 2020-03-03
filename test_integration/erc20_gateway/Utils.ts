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

const rlp = require('rlp');

import shared from './shared';

/**
 * It contains utility methods for integration tests.
 */
export default class Utils {

  /**
   * It calculates storage path for a key.
   *
   * @param storageIndex Index at which contract key is present in the contract.
   * @param mappings List of keys in case storage is mapping.
   */
  static async storagePath(
    storageIndex: string,
    mappings: any,
  ) {
    let path = '';
    if (mappings && mappings.length > 0) {
      mappings.map((mapping) => {
        path = `${path}${shared.web3.utils.padLeft(mapping, 64)}`;
        return path;
      });
    }
    path = `${path}${shared.web3.utils.padLeft(storageIndex, 64)}`;
    path = shared.web3.utils.sha3(path);

    return path;
  }

  /**
   * It serializes the array of node keys for account or storage proof.
   *
   * @param proof Array of account or storage keys.
   */
  static formatProof(
    proof: string[],
    ): string {
    const formattedProof = proof.map(p => rlp.decode(p));
    return `0x${rlp.encode(formattedProof).toString('hex')}`;
  }

  /**
   * It returns block information for a block number.
   *
   * @param blockNumber Block number for which block information is required.
   */
  static async getBlock(blockNumber: string) {
    const block = await shared.web3.eth.getBlock(blockNumber);
    return block;
  }

  /**
   * It provides account proof for an address.
   *
   * @param contractAddress Contract address for which account proof is required.
   * @param blockNumber Block number at which proof is required.
   */
  static async getAccountProof(
    contractAddress: string,
    blockNumber: string,
  ): Promise<{encodedAccountValue, serializedProof}> {
    const proof = await Utils.getProof(
      contractAddress,
      [],
      blockNumber,
    );

    const encodedAccountValue = Utils.encodedAccountValue(proof.accountProof);
    const serializedProof = Utils.formatProof(proof.accountProof);
    return {
      encodedAccountValue,
      serializedProof,
    };
  }

  /**
   * It provides rlp serialized account node.
   *
   * @param accountProof Array of nodes of account proof.
   */
  private static encodedAccountValue(accountProof: string[]): string {
    const decodedProof = accountProof.map((proof) => rlp.decode(proof));;
    const leafElement = decodedProof[decodedProof.length - 1];
    return `0x${leafElement[leafElement.length - 1].toString('hex')}`;
  }

  /**
   * It uses web3's getProof method to account and storage proof for an contract.
   *
   * @param contractAddress Contract address for which proof is required.
   * @param storagePath Array of storage keys to get storage proof.
   * @param blockNumber Block number at which proof is required.
   */
  static async getProof(
    contractAddress: string,
    storagePath: string[],
    blockNumber: string,
  ) {
    const proof = await shared.web3.eth.getProof(
      contractAddress,
      storagePath,
      blockNumber,
    );

    return proof;
  }

  /**
   * It returns storage proof for an contract's key.
   *
   * @param contractAddress Contract address for which proof is required.
   * @param storagePath Array of storage keys to get storage proof.
   * @param blockNumber Block number at which proof is required.
   */
  static async getStorageProof(
    contractAddress: string,
    storagePath: string[],
    blockNumber: string,
  ): Promise<string>{
    const proof = await Utils.getProof(
      contractAddress,
      storagePath,
      blockNumber,
    );
    const serializedStorageProof = Utils.formatProof(proof.storageProof[0].proof);

    return serializedStorageProof;
  }

  /**
   * Send Transaction.
   * @param rawTx Raw Transaction object.
   * @param txOptions Transaction Options.
   */
  static async sendTransaction(
    rawTx: any,
    txOptions: {
      gas?: string,
      gasPrice?: string,
      from: string,
    }) {
    txOptions.gas = txOptions.gas
      ? txOptions.gas
      : (await rawTx.estimateGas({ from: txOptions.from })).toString();

    return rawTx.send(txOptions);
  }
}
