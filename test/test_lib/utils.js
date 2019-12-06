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

const Assert = require('assert');
const BN = require('bn.js');
const web3 = require('./web3.js');

async function advanceBlock() {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      method: 'evm_mine',
      jsonrpc: '2.0',
      id: 1337,
    },
    (err) => {
      if (err) {
        return reject(err);
      }

      const newBlockHash = web3.eth.getBlock('latest').hash;

      return resolve(newBlockHash);
    });
  });
}

function getRandomHash() { return web3.utils.sha3(`${Date.now()}`); }

const ResultType = {
  FAIL: 0,
  SUCCESS: 1,
};
Object.freeze(ResultType);

/**
 * Asserts that an error message contains a string given as message. Always
 * passes if the message is `undefined`.
 *
 * @param {string} message A regular expression that the error should contain.
 * @param {Object} error The error.
 */
function assertExpectedMessage(message, error) {
  if (message !== undefined) {
    assert(
      error.message.search(message) > -1,
      `The contract was expected to error including "${message}", but instead: "${
        error.message
      }"`,
    );
  }
}

/** Tracking Gas Usage. */
const receipts = [];

function Utils() {}

Utils.prototype = {
  generateRandomMetachainId: () => getRandomHash().substr(0, 20),

  /** Log receipt. */
  logReceipt: (receipt, description) => {
    receipts.push({
      receipt,
      description,
      response: null,
    });
  },

  /** Print gas statistics. */
  printGasStatistics: () => {
    let totalGasUsed = 0;

    console.log('      -----------------------------------------------------');
    console.log('      Report gas usage\n');

    for (let i = 0; i < receipts.length; i += 1) {
      const entry = receipts[i];

      totalGasUsed += entry.receipt.gasUsed;

      console.log(
        `      ${entry.description.padEnd(45)}${entry.receipt.gasUsed}`,
      );
    }

    console.log('      -----------------------------------------------------');
    console.log(`      ${'Total gas logged: '.padEnd(45)}${totalGasUsed}\n`);
  },

  /** Clear receipt. */
  clearReceipts: () => {
    receipts.splice(0, receipts.length);
  },

  /**
   * Asserts no events in the receipt.
   * @param result Receipt
   */
  expectNoEvents: (result) => {
    Assert.equal(
      result.receipt.logs.length,
      0,
      'expected empty array of logs',
    );
  },

  /**
   * Expect failure from invalid opcode or out of gas, but returns error
   * instead.
   * @param promise Contract method call.
   * @param expectedMessage Message needs to be asserted.
   */
  expectThrow: async (promise, expectedMessage) => {
    try {
      await promise;
    } catch (error) {
      if (expectedMessage !== undefined) {
        assertExpectedMessage(expectedMessage, error);
      } else {
        const invalidOpcode = error.message.search('invalid opcode') > -1;
        const outOfGas = error.message.search('out of gas') > -1;
        // Latest TestRPC has trouble with require
        const revertInstead = error.message.search('revert') > -1;
        const invalidAddress = error.message.search('invalid address') > -1;

        assert(
          invalidOpcode || outOfGas || revertInstead || invalidAddress,
          `Expected throw, but got ${error} instead`,
        );
      }

      return;
    }

    assert(false, `Did not throw with error message: ${expectedMessage}`);
  },

  /**
   * Asserts that a given ethereum call/transaction leads to a revert. The
   * call/transaction is given as a promise.
   *
   * @param {promise} promise Awaiting this promise must lead to a revert.
   * @param {string} expectedMessage If given, the returned error message must
   *                                 include this string (optional).
   */
  expectRevert: async (promise, expectedMessage) => {
    try {
      await promise;
    } catch (error) {
      assert(
        error.message.search('revert') > -1,
        `The contract should revert. Instead: ${error.message}`,
      );

      assertExpectedMessage(expectedMessage, error);
      return;
    }

    assert(false, `Did not revert with expected error message: ${expectedMessage}`);
  },

  /**
   * Asserts that a given ethereum call/transaction leads to a assert failure.
   * The call/transaction is given as a promise.
   *
   * @param {promise} promise Awaiting this promise must lead to a error.
   * @param {string} expectedMessage If given, the returned error message must
   *                                 include this string (optional).
   */
  expectFailedAssert: async (promise, expectedMessage) => {
    try {
      await promise;
    } catch (error) {
      assert(
        error.message.search('Returned error:') > -1,
        `The contract should fail an assert. Instead: ${error.message}`,
      );

      assertExpectedMessage(expectedMessage, error);
      return;
    }

    assert(false, 'Did not fail assert as expected.');
  },

  /** Get block number. */
  getBlockNumber: () => new Promise((resolve, reject) => {
    web3.eth.getBlockNumber((error, result) => {
      if (error) {
        reject(error);
      } else {
        resolve(new BN(result));
      }
    });
  }),

  /** Get block hash */
  getBlockHash: blockNumber => new Promise((resolve) => {
    web3.eth.getBlock(blockNumber).then(block => resolve(block.hash));
  }),

  /** Get account balance. */
  getBalance: address => new Promise((resolve, reject) => {
    web3.eth.getBalance(address, (error, result) => {
      if (error) {
        reject(error);
      } else {
        resolve(new BN(result));
      }
    });
  }),

  getStorageAt: (address, index) => new Promise(
    resolve => web3.eth.getStorageAt(address, index)
      .then(result => resolve(result)),
  ),

  /** Get gas price. */
  getGasPrice: () => new Promise((resolve, reject) => {
    web3.eth.getGasPrice((error, result) => {
      if (error) {
        reject(error);
      } else {
        resolve(result);
      }
    });
  }),

  getCode: address => new Promise((resolve) => {
    web3.eth.getCode(address)
      .then((code) => {
        resolve(code);
      });
  }),

  validateEvents: (eventLogs, expectedData) => {
    assert.equal(
      eventLogs.length,
      Object.keys(expectedData).length,
      'Number of events emitted must match expected event counts',
    );
    eventLogs.forEach((event) => {
      const eventName = event.event;
      const eventData = Object.keys(event.args);
      const eventExpectedData = expectedData[eventName];

      assert.notEqual(
        eventExpectedData,
        undefined,
        'Expected event not found',
      );

      eventData.forEach((element) => {
        const key = element;
        if (eventExpectedData[key]) {
          if (web3.utils.isBN(eventExpectedData[key])) {
            assert(
              event.args[key].eq(eventExpectedData[key]),
              `Event data ${key} must match the expectedData`,
            );
          } else {
            assert.strictEqual(
              event.args[key],
              eventExpectedData[key],
              `Event data ${key} must match the expectedData`,
            );
          }
        }
      });
    });
  },

  advanceBlocks: async (amount) => {
    for (let i = 0; i < amount; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await advanceBlock();
    }
  },

  getTypeHash: structDescriptor => web3.utils.sha3(
    web3.eth.abi.encodeParameter('string', structDescriptor),
  ),

  getCallPrefix: (structDescriptor) => {
    const hash = web3.utils.sha3(structDescriptor);
    return hash.substring(0, 10);
  },

  getRandomHash,

  getRandomNumber: max => Math.floor(Math.random() * Math.floor(max)),

  /** Receives accounts list and gives away each time one. */
  AccountProvider: class AccountProvider {
    constructor(accounts) {
      this.accounts = accounts;
      this.index = 0;
    }

    get() {
      assert(this.index < this.accounts.length);
      const account = this.accounts[this.index];
      this.index += 1;
      return account;
    }
  },

  encodeFunctionSignature: signature => web3.eth.abi.encodeFunctionSignature(signature),
  encodeParameters: (types, params) => web3.eth.abi.encodeParameters(types, params),

  isAddress: address => web3.utils.isAddress(address),

  isNonNullAddress: address => web3.utils.isAddress(address) && address !== this.NULL_ADDRESS,

  toChecksumAddress: address => web3.utils.toChecksumAddress(address),

  ResultType,

  ZERO_BYTES32:
    '0x0000000000000000000000000000000000000000000000000000000000000000',

  ZERO_BYTES20:
    '0x0000000000000000000000000000000000000000',

  NULL_ADDRESS: '0x0000000000000000000000000000000000000000',
};

module.exports = new Utils();
