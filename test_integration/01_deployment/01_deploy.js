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

const shared = require('../shared');

describe('Deployment', async () => {
  before(async () => {

  });

  it('Contract deployment', async () => {
    const {
      Axiom,
      Committee,
      Consensus,
      Core,
      Reputation,
    } = shared.artifacts;

    const committee = await Committee.new();
    const consensus = await Consensus.new();
    const reputation = await Reputation.new();
    const core = await Core.new();
    const axiom = await Axiom.new(
      shared.origin.keys.techGov,
      consensus.address,
      core.address,
      committee.address,
      reputation.address,
    );

    shared.origin.contracts.Axiom.address = axiom.address;
    shared.origin.contracts.Core.address = core.address;
    shared.origin.contracts.Reputation.address = reputation.address;
    shared.origin.contracts.Consensus.address = consensus.address;
    shared.origin.contracts.Committee.address = committee.address;

    // todo add contract instance to shared once auto generated interact PR is merged.
    // Example shared.origin.contracts.Committee.instance =
    // Interacts.getCommittee(committeeAddress, web3);
  });
});
