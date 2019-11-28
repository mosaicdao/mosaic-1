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

import shared from "./shared";
const EthUtils = require('ethereumjs-util');

export default class Utils {
  /**
   * Fund address for gas with ETH
   * @param beneficiary Beneficiary Address.
   * @param funder Funder Address.
   * @param web3 Web3 instance.
   * @param value Amount in wei.
   */
  static fundAddressForGas(beneficiary: string, funder:string, web3, value: string) {
    return web3.eth.sendTransaction(
      {
        from: funder,
        to: beneficiary,
        value,
      },
    );
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
      from: string
    }) {
    txOptions.gas = txOptions.gas
      ? txOptions.gas
      : (await rawTx.estimateGas(txOptions)).toString();
    return rawTx.send(txOptions);
  }

  /**
   * Returns code at given address.
   *
   * @param web3 Web3 provider
   * @param address Contract address
   * @return {Promise<string>}
   */
  static getCode(web3, address): Promise<string> {
    return web3.eth.getCode(address);
  }

  /**
   * Returns random sha3 value
   * @param web3 Web3 provider
   * @return Sha3 value
   */
  static randomSha3(web3): string {
    const randomString = Math.random().toString(36).substring(2, 15);
    return web3.utils.sha3(randomString);
  }

  /**
   * Returns signatures
   * @param web3 Web3 provider
   * @param proposalHash proposal value
   * @param privateKey Private key
   * @return r, s, v signature values
   */
  static signProposal(web3, proposalHash, privateKey): {r: string, s: string, v: string} {
    const proposalSignature = EthUtils.ecsign(
      EthUtils.toBuffer(proposalHash),
      EthUtils.toBuffer(privateKey),
    );

    return {
      r: EthUtils.bufferToHex(proposalSignature.r),
      s: EthUtils.bufferToHex(proposalSignature.s),
      v: web3.utils.toDecimal(proposalSignature.v),
    };
  }
}

export enum ValidatorStatus {
  Undefined = 0,
  Slashed = 1,
  Staked = 2,
  LoggedOut = 3,
  Withdrawn = 4,
}

export enum CoreStatus {
  undefined = 0,
  halted = 1,
  corrupted = 2,
  creation = 3,
  opened = 4,
  precommitted = 5,
};


