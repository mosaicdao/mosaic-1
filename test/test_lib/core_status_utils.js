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

const BN = require('bn.js');

const CoreStatus = {
  undefined: 0,
  halted: 1,
  corrupted: 2,
  creation: 3,
  opened: 4,
  precommitted: 5,
};
Object.freeze(CoreStatus);

function isCoreCreated(status) {
  return new BN(CoreStatus.creation).cmp(status) === 0;
}

function isCoreOpened(status) {
  return new BN(CoreStatus.opened).cmp(status) === 0;
}

function isCorePrecommitted(status) {
  return new BN(CoreStatus.precommitted).cmp(status) === 0;
}

function isCoreHalted(status) {
  return new BN(CoreStatus.halted).cmp(status) === 0;
}

function isCoreCorrupted(status) {
  return new BN(CoreStatus.corrupted).cmp(status) === 0;
}

module.exports = {
  isCoreCreated,
  isCoreOpened,
  isCorePrecommitted,
  isCoreHalted,
  isCoreCorrupted,
  CoreStatus,
};
