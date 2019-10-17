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

const Axiom = artifacts.require('Axiom');

const ConsensusSetupCallPrefix = 'setup(uint256,uint256,uint256,uint256,uint256,address)';
const ReputationSetupCallPrefix = 'setup(address,address,uint256,address,uint256,uint256,uint256,uint256)';

async function deployAxiom(
  techGov,
  consensusMasterCopy,
  coreMasterCopy,
  committeeMasterCopy,
  reputationMasterCopy,
  txOptions,
) {
  const axiom = await Axiom.new(
    techGov,
    consensusMasterCopy,
    coreMasterCopy,
    committeeMasterCopy,
    reputationMasterCopy,
    txOptions,
  );
  return axiom;
}

async function deployAxiomWithConfig(config) {
  return deployAxiom(
    config.techGov,
    config.consensusMasterCopy,
    config.coreMasterCopy,
    config.committeeMasterCopy,
    config.reputationMasterCopy,
    config.txOptions,
  );
}
module.exports = {
  deployAxiom,
  deployAxiomWithConfig,
  ConsensusSetupCallPrefix,
  ReputationSetupCallPrefix,
};
