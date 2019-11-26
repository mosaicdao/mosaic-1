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
//
// ----------------------------------------------------------------------------
//
// http://www.simpletoken.org/
//
// ----------------------------------------------------------------------------
const Web3 = require('web3');

const web3 = new Web3('http://localhost:8545');
// For testing use 1 block confirmation.
web3.transactionConfirmationBlocks = 1;

/**
 * An object that is shared across modules.
 *
 * @property {Object} artifacts The truffle artifacts of the contracts. Indexed
 *     by the contract name, as written in the solidity source
 *     file.
 */
const shared = {
  artifacts: {},
  origin: {
    funder: '', // Address that holds mOST and wETH funds.
    web3,
    keys: {
      techGov: '', // This values will pe populated in key_generation.
      validators: [],
    },
    contracts: {
      Axiom: {
        address: '',
        instance: {},
      },
      Committee: {
        address: '',
        instance: {},
      },
      Consensus: {
        address: '',
        instance: {},
      },
      Core: {
        address: '',
        instance: {},
      },
      Reputation: {
        address: '',
        instance: {},
      },
      MOST: {
        address: '',
        instance: {},
      },
      WETH: {
        address: '',
        instance: {},
      },
    },
  },
};

/**
 * @returns {Shared} The shared object.
 */
module.exports = shared;
