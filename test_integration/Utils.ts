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

import {TransactionObject} from "../interacts/types";

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

  static getCode(web3, address): Promise<string> {
    return web3.eth.getCode(address);
  }
}

