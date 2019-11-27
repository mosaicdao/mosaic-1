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
import Interacts from "../../interacts/Interacts";
import chai = require('chai');
const { assert } = chai;

describe('Axiom::setupConsensus', async () => {
  it('TechGov calls Axiom.setupConsensus', async () => {

    const axiomInstance = shared.origin.contracts.Axiom;
    const committeeSize = '3';
    const minValidators = '5';
    const joinLimit = '10';
    const gasTargetDelta = '15000000';
    const coinbaseSplitPerMille = '499';
    const mOSTAddress = shared.origin.contracts.MOST.address;
    const stakeMOSTAmount = '1000';
    const wETHAddress = shared.origin.contracts.WETH.address;
    const stakeWETHAmount = '500';
    const cashableEarningsPerMille = '100';
    const initialReputation = '1';
    const withdrawalCooldownPeriodInBlocks = '20';
    const txOptions = {
      from: shared.origin.keys.techGov,
    };
    await axiomInstance.methods.setupConsensus(
      committeeSize,
      minValidators,
      joinLimit,
      gasTargetDelta,
      coinbaseSplitPerMille,
      mOSTAddress,
      stakeMOSTAmount,
      wETHAddress,
      stakeWETHAmount,
      cashableEarningsPerMille,
      initialReputation,
      withdrawalCooldownPeriodInBlocks,
    );
    // TODO send transaction
    const reputationContractAddress = await axiomInstance.methods.reputation().call();
    shared.origin.contracts.Reputation.instance = Interacts.getReputation(
      shared.origin.web3,
      reputationContractAddress,
    );

    const consensusContractAddress = await axiomInstance.methods.consensus().call();
    shared.origin.contracts.Consensus.instance = Interacts.getConsensus(
      shared.origin.web3,
      consensusContractAddress,
    );
    const consensusInstance = shared.origin.contracts.Consensus.instance;

    // Assert consensus state variables
    assert.strictEqual(
      await consensusInstance.methods.committeeSize().call(),
      committeeSize,
      'Committee size value is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.minValidators().call(),
      minValidators,
      'Min validators value is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.joinLimit().call(),
      joinLimit,
      'Join limit value is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.gasTargetDelta().call(),
      gasTargetDelta,
      'Gas target delta value is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.coinbaseSplitPerMille().call(),
      coinbaseSplitPerMille,
      'Coin base split percentage value is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.reputation().call(),
      reputationContractAddress,
      'Reputation value is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.axiom().call(),
      shared.origin.contracts.Axiom.address,
      'Axiom contract address is not set in the contract.',
    );

    assert.strictEqual(
      await consensusInstance.methods.committees('0x1'),
      await consensusInstance.methods.SENTINEL_COMMITTEES().call(),
      'Committee sentinel value is not correctly set in the contract.',
    );

    // Assert reputation state variables
    const reputationsInstance = shared.origin.contracts.Reputation.instance;
    assert.strictEqual(
      await reputationsInstance.methods.consensus().call(),
      consensusContractAddress,
      'Consensus contract address is not set in the contract.',
    );

    assert.strictEqual(
      await reputationsInstance.methods.mOST().call(),
      mOSTAddress,
      'mOST contract address is not set in the contract.',
    );

    assert.strictEqual(
      await reputationsInstance.methods.stakeMOSTAmount().call(),
      stakeMOSTAmount,
      'Stake mOST amount is not set in the contract.',
    );

    assert.strictEqual(
      await reputationsInstance.methods.wETH().call(),
      wETHAddress,
      'wETH contract address is not set in the contract.',
    );

    assert.strictEqual(
      reputationsInstance.methods.stakeWETHAmount().call(),
      stakeWETHAmount,
      'Stake wETH amount is not set in the contract.',
    );


    assert.strictEqual(
      reputationsInstance.methods.cashableEarningsPerMille().call(),
      cashableEarningsPerMille,
      'Cashable earnings per mille value is not set in the contract.',
    );

    assert.strictEqual(
      reputationsInstance.methods.initialReputation().call(),
      initialReputation,
      'Initial reputation value is not set in the contract.',
    );

    assert.strictEqual(
      reputationsInstance.methods.withdrawalCooldownPeriodInBlocks().call(),
      withdrawalCooldownPeriodInBlocks,
      'Withdrawal cooldown period in blocks value is not set in the contract.',
    );
  });

});
