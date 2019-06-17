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
const web3 = require('../test_lib/web3.js');
const CommitteeUtils = require('./utils.js');

contract('Committee::constructor', (accounts) => {
  let committeeSize = new BN(10);
  let dislocation = web3.utils.sha3('dislocation');
  let proposal = web3.utils.sha3('proposal');

  it('should construct given sensible parameters', async () => {

    const committee = await CommitteeUtils.createCommittee(
      committeeSize,
      dislocation,
      proposal,
    );

    const committeeConsensus = await committee.consensus.call();
    assert.strictEqual(
      committeeConsensus == accounts[0],
      true,
      `Consensus contract is set to ${committeeConsensus} and is not ${accounts[0]}.`,
    );

    const committeeProposal = await committee.proposal.call();
    assert.strictEqual(
      committeeProposal == proposal,
      true,
      `Proposals don't match.`
    );

    const committeeDislocation = await committee.dislocation.call();
    assert.strictEqual(
      committeeDislocation == dislocation,
      true,
      `Dislocation doesn't match.`
    );
  });

  // it('should fail when organization address is zero', async () => {
  //   organization = NullAddress;

  //   await Utils.expectRevert(
  //     Anchor.new(
  //       remoteChainId,
  //       blockHeight,
  //       stateRoot,
  //       maxNumberOfStateRoots,
  //       organization,
  //     ),
  //     'Organization contract address must not be zero.',
  //   );
  // });

  // it('should pass with correct params', async () => {
  //   anchor = await Anchor.new(
  //     remoteChainId,
  //     blockHeight,
  //     stateRoot,
  //     maxNumberOfStateRoots,
  //     organization,
  //   );

  //   const chainId = await anchor.getRemoteChainId.call();
  //   assert.strictEqual(
  //     remoteChainId.eq(chainId),
  //     true,
  //     `Remote chain id from the contract must be ${remoteChainId}.`,
  //   );

  //   const latestBlockHeight = await anchor.getLatestStateRootBlockHeight.call();
  //   assert.strictEqual(
  //     blockHeight.eq(latestBlockHeight),
  //     true,
  //     `Latest block height from the contract must be ${blockHeight}.`,
  //   );

  //   const latestStateRoot = await anchor.getStateRoot.call(blockHeight);
  //   assert.strictEqual(
  //     latestStateRoot,
  //     stateRoot,
  //     `Latest state root from the contract must be ${stateRoot}.`,
  //   );

  //   const organizationAddress = await anchor.organization.call();
  //   assert.strictEqual(
  //     organizationAddress,
  //     organization,
  //     `Organization address from the contract must be ${organization}.`,
  //   );
  // });
});
