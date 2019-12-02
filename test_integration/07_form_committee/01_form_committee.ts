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
const { assert } = chai;
import Utils, {NULL_ADDRESS} from "../Utils";

describe('Consensus::formCommittee', async () => {

  it('Consensus.formCommittee is called', async () => {
    const txOptions = {
      from: shared.origin.funder,
    };
    const consensusInstance = shared.origin.contracts.Consensus.instance;
    const committeeFormationDelay = await consensusInstance.methods.COMMITTEE_FORMATION_DELAY().call();
    // Advance by committeeFormationDelay
    await Utils.advanceBlocks(shared.origin.web3, committeeFormationDelay);
    // Advance by 256 blocks
    const segmentLength = 256;
    await Utils.advanceBlocks(shared.origin.web3, segmentLength);
    const txObject = await consensusInstance.methods.formCommittee(
      shared.origin.contracts.Core.address,
    );
    await Utils.sendTransaction(txObject, txOptions);

    const committeeAddress = await consensusInstance.methods.proposals(shared.data.proposal).call();
    assert.strictEqual(
      Utils.isAddress(shared.origin.web3, committeeAddress) && committeeAddress !== NULL_ADDRESS,
      true,
      `${committeeAddress} must be a valid non null ethereum address.`,
    );
  });

});
