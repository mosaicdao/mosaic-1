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

import BN from 'bn.js';
const assert = require('assert');

export default class Assert {

  /**
   * Assertion for GatewayProven event.
   *
   * @param event GatewayProven event.
   * @param expectedInboxAddress Expected Inbox address.
   * @param expectedBlockNumber Expected block number.
   */
  public static assertGatewayProven(
    event: {returnValues: {}},
    expectedInboxAddress: string,
    expectedBlockNumber: BN,
  ) {
    assert.strictEqual(
      event.returnValues['remoteGateway'],
      expectedInboxAddress,
      'Incorrect remote gateway address',
    );

    assert.strictEqual(
      expectedBlockNumber.eq(new BN(event.returnValues['blockNumber'])),
      true,
      `Expected block number for gateway proven is ${expectedBlockNumber.toString(10)}`
      + ` but got ${event.returnValues['blockNumber']} `,
    );
  }

  /**
   * Assertion for StateRootAvailable event.
   *
   * @param event StateRootAvailable event.
   * @param blockNumber Block number at which anchoring is done.
   * @param stateroot State root for a block.
   */
  public static assertAnchor(
    event: { returnValues: {} },
    blockNumber: BN,
    stateroot: string,
  ) {

    assert.strictEqual(
      blockNumber.eq(new BN(event.returnValues['_blockNumber'])),
      true,
      `Expected blocknumber at which anchoring is done ${blockNumber.toString(10)} but got`
      + `${event.returnValues['_blockNumber']}`,
    );

    assert.strictEqual(
      event.returnValues['_stateRoot'],
      stateroot,
      'Incorrect state root',
    );
  }
}
