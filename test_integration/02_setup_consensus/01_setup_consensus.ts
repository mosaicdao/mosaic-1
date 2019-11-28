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
import Utils from "../Utils";
const { assert } = chai;

describe('Axiom::setupConsensus', async () => {
  it('TechGov calls Axiom.setupConsensus', async () => {

    const axiomInstance = shared.origin.contracts.Axiom.instance;
    const committeeSize = '3';
    const minValidators = '5';
    const joinLimit = '10';
    const gasTargetDelta = '15000000'; // 15 million
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
    const txObject = await axiomInstance.methods.setupConsensus(
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
    await Utils.sendTransaction(
      txObject,
      txOptions,
    );

    // Set reputation instance
    const reputationContractAddress = await axiomInstance.methods.reputation().call();
    shared.origin.contracts.Reputation.instance = Interacts.getReputation(
      shared.origin.web3,
      reputationContractAddress,
    );
    shared.origin.contracts.Reputation.address = reputationContractAddress;

    // Set consensus instance
    const consensusContractAddress = await axiomInstance.methods.consensus().call();
    shared.origin.contracts.Consensus.instance = Interacts.getConsensus(
      shared.origin.web3,
      consensusContractAddress,
    );
    shared.origin.contracts.Consensus.address = consensusContractAddress;
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
      await consensusInstance.methods.committees('0x0000000000000000000000000000000000000001').call(),
      await consensusInstance.methods.SENTINEL_COMMITTEES().call(),
      'Committee sentinel value is not correctly set in the contract.',
    );

    // Assert reputation state variables
    const reputationInstance = shared.origin.contracts.Reputation.instance;
    assert.strictEqual(
      await reputationInstance.methods.consensus().call(),
      shared.origin.contracts.Consensus.address,
      'Consensus contract address is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.mOST().call(),
      mOSTAddress,
      'mOST contract address is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.stakeMOSTAmount().call(),
      stakeMOSTAmount,
      'Stake mOST amount is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.wETH().call(),
      wETHAddress,
      'wETH contract address is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.stakeWETHAmount().call(),
      stakeWETHAmount,
      'Stake wETH amount is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.cashableEarningsPerMille().call(),
      cashableEarningsPerMille,
      'Cashable earnings per mille value is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.initialReputation().call(),
      initialReputation,
      'Initial reputation value is not set in the contract.',
    );

    assert.strictEqual(
      await reputationInstance.methods.withdrawalCooldownPeriodInBlocks().call(),
      withdrawalCooldownPeriodInBlocks,
      'Withdrawal cooldown period in blocks value is not set in the contract.',
    );
  });

});
