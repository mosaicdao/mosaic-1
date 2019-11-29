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
import Utils, {CoreStatus} from "../Utils";
const { assert } = chai;

describe('Core::registerVote', async () => {
  it('Core.registerVote is called', async () => {
    const coreInstance = shared.origin.contracts.Core.instance;
    const txOptions = {
      from: shared.origin.keys.techGov,
    };
    const proposalHash = shared.data.proposal;
    const validators = shared.origin.keys.validators;
    const quorum = await coreInstance.methods.quorum().call();
    for(let i = 0; i <= parseInt(quorum); i++) {
      const validator = validators[i];
      console.log(`signing validator: ${validator.address}`);
      const signature = Utils.signProposal(
        shared.origin.web3,
        proposalHash,
        validator.privateKey,
      );
      const txObject = coreInstance.methods.registerVote(
        proposalHash,
        signature.r,
        signature.s,
        signature.v,
      );
      await Utils.sendTransaction(txObject, txOptions);
    }

    assert.strictEqual(
      await coreInstance.methods.precommit().call(),
      proposalHash,
      'Core precommit value is incorrect.'
    );

    assert.strictEqual(
      await coreInstance.methods.coreStatus().call(),
      CoreStatus.precommitted,
      'Core status is not preCommitted.'
    );

    const consensusInstance = shared.origin.contracts.Consensus.instance;
    const coreAddress = shared.origin.contracts.Core.address;
    assert.strictEqual(
      await consensusInstance.methods.precommits(coreAddress).call(),
      proposalHash,
      'Proposal for core is incorrect in Consensus contract.',
    );

  });

});
