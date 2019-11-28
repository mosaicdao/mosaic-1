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

import shared from '../shared';
import chai = require('chai');
import Utils from "../Utils";
import BN = require("bn.js");
const { assert } = chai;

describe('Axiom::setupConsensus', async () => {
  it('TechGov calls Axiom.setupConsensus', async () => {
    const coreInstance = shared.origin.contracts.Core.instance;
    const kernelHash = coreInstance.methods.openKernelHash().call();
    const originObservation = Utils.randomSha3();
    const dynasty = '1'; // default is '0'
    const accumulatedGas = '1500000';
    const secret = 'secret';
    const committeeLock = shared.origin.web3.utils.sha3(secret);
    const source = shared.origin.web3.utils.sha3('100block');
    const target = shared.origin.web3.utils.sha3('200block');
    const epochLength = await coreInstance.methods.epochLength().call();
    const sourceBlockHeight = new BN(epochLength).add(new BN('100'));
    const targetBlockHeight = sourceBlockHeight.add(new BN(epochLength));
    const proposalHash = await coreInstance.methods.proposeMetablock(
      kernelHash.toString(),
      originObservation,
      dynasty,
      accumulatedGas,
      committeeLock,
      source,
      target,
      sourceBlockHeight.toString(),
      targetBlockHeight.toString(),
    ).call();
    const txObject = await coreInstance.methods.proposeMetablock(
      kernelHash.toString(),
      originObservation,
      dynasty,
      accumulatedGas,
      committeeLock,
      source,
      target,
      sourceBlockHeight.toString(),
      targetBlockHeight.toString(),
    );
    const txOptions = {
      from: shared.origin.keys.techGov,
    };
    await Utils.sendTransaction(
      txObject,
      txOptions,
    );

    const voteCount = await coreInstance.methods.voteCounts(proposalHash).call();
    assert.strictEqual(
      voteCount.dynasty,
      dynasty,
      'Invalid dynasty value.',
    );

    assert.strictEqual(
      voteCount.height,
      await coreInstance.methods.openKernelHeight().call(),
      'Invalid open kernel height value.',
    );

    assert.strictEqual(
      voteCount.count,
      '0',
      'Invalid vote count value.',
    );
  });

});
