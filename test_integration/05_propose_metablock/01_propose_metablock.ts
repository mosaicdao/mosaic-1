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
import * as Web3Utils from 'web3-utils';
const { assert } = chai;


describe('Core::proposeMetablock', async () => {
  it('Core.proposeMetablock is called', async () => {
    const coreInstance = shared.origin.contracts.Core.instance;
    const kernelHash = await coreInstance.methods.openKernelHash().call();
    // TODO ganache block hash 10
    const originObservation = Utils.randomSha3(shared.origin.web3); // Finalized block hash
    const dynasty = '1'; // default is '0'
    const accumulatedGas = '10000000'; // 10 million
    const secret = Web3Utils.randomHex(32); // transaction root
    const committeeLock = shared.origin.web3.utils.sha3(secret);
    // TODO Advance block by 150
    // Get actual ganache block hash of finalized blocks
    const source = shared.origin.web3.utils.sha3('sourceBlockHash');
    const target = shared.origin.web3.utils.sha3('targetBlockHash');
    const epochLength = await coreInstance.methods.epochLength().call();
    const sourceBlockHeight = new BN(epochLength).add(new BN('100'));
    const targetBlockHeight = sourceBlockHeight.add(new BN(epochLength));
    const txOptions = {
      from: shared.origin.keys.techGov,
    };
    const proposalHash = await coreInstance.methods.proposeMetablock(
      kernelHash,
      originObservation,
      dynasty,
      accumulatedGas,
      committeeLock,
      source,
      target,
      sourceBlockHeight.toString(10),
      targetBlockHeight.toString(10),
    ).call();
    const txObject = coreInstance.methods.proposeMetablock(
      kernelHash,
      originObservation,
      dynasty,
      accumulatedGas,
      committeeLock,
      source,
      target,
      sourceBlockHeight.toString(10),
      targetBlockHeight.toString(10),
    );
    await Utils.sendTransaction(
      txObject,
      txOptions,
    );

    // Set proposal in data variable
    shared.data.proposal = proposalHash;
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
  });

});
