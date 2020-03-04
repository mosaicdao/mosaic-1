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

import Mocha from 'mocha';
import shared from './shared';

/**
 * @file Truffle's `artifacts.require()` won't be available inside the Mocha
 * tests. Thus, we load them here and add them to the `shared` object.
 */

'use strict';

// @ts-ignore
const Anchor = artifacts.require('Anchor');

// @ts-ignore
const ERC20Gateway = artifacts.require('ERC20Gateway');

// @ts-ignore
const ERC20Cogateway = artifacts.require('Gen0ERC20Cogateway');

// @ts-ignore
const ERC20Token = artifacts.require('ERC20Mock');

// @ts-ignore
const UtilityToken = artifacts.require('UtilityToken');

const setupArtifacts = () => {
  shared.artifacts = {
    Anchor,
    ERC20Gateway,
    ERC20Cogateway,
    ERC20Token,
    UtilityToken,
  };
};

const runTests = (callback) => {
  const mocha = new Mocha({
    enableTimeouts: false,
  });

  Mocha.utils.lookupFiles(__dirname, ['js'], true)
    .filter(
      // Skipping this file so that artifacts are not loaded.
      file => file !== __filename,
    )
    .forEach((file) => {
      mocha.addFile(file);
    });

  mocha.run((failures) => {
    callback(failures);
  });
};

module.exports = (callback) => {
  setupArtifacts();
  runTests(callback);
};
