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

const CircularBufferUint = artifacts.require('CircularBufferUintTest');

const Utils = require('../../test_lib/utils.js');

contract('CircularBufferUint::setupCircularBuffer', (accounts) => {
  let circularBufferUint;
  const size = 100;

  beforeEach(async () => {
    circularBufferUint = await CircularBufferUint.new();
  });

  it('should setup circular Buffer uint', async () => {
    await circularBufferUint.setupCircularBufferExternal(size);
  });

  it('should fail to setup circular Buffer uint if already setup', async () => {
    await circularBufferUint.setupCircularBufferExternal(size);

    await Utils.expectRevert(
      circularBufferUint.setupCircularBufferExternal(size),
      'Circular buffer size can be setup once.',
    );
  });
});
