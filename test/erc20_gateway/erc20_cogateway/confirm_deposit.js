'use-strict';

// Copyright 2020 OpenST Ltd.
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

const BN = require('bn.js');

const UtilityToken = artifacts.require('UtilityToken');
const ERC20Cogateway = artifacts.require('ERC20CogatewayDouble');

const TestData = require('../../../test/erc20_gateway/data/erc20_deposit_proof.json');

contract('ERC20Cogateway::confirmDeposit', async (accounts) => {
  let erc20Cogateway;
  let setupGenesisParams;
  let utilityToken;
  let param = {};

  beforeEach(async () => {
    erc20Cogateway = await ERC20Cogateway.new();
    utilityToken = await UtilityToken.new();

    param = {
      amount: TestData.param.amount,
      beneficiary: TestData.param.beneficiary,
      feeGasPrice: TestData.param.feeGasPrice,
      feeGasLimit: TestData.param.feeGasLimit,
      valueToken: TestData.valueToken,
      depositor: TestData.address,
      blockNumber: TestData.blockNumber,
      rlpParentNodes: TestData.storageProof,
    };
    setupGenesisParams = {
      genesisMetachainId: TestData.metachainId,
      genesisERC20Gateway: TestData.erc20Gateway,
      genesisStateRootProvider: TestData.stateRootProvider,
      genesisMaxStorageRootItems: new BN(50),
      genesisOutboxStorageIndex: new BN(1),
      genesisUtilityTokenMastercopy: utilityToken.address,
    };
    await erc20Cogateway.setupGenesis(
      setupGenesisParams.genesisMetachainId,
      setupGenesisParams.genesisERC20Gateway,
      setupGenesisParams.genesisStateRootProvider,
      setupGenesisParams.genesisMaxStorageRootItems,
      setupGenesisParams.genesisOutboxStorageIndex,
      setupGenesisParams.genesisUtilityTokenMastercopy,
    );
    await erc20Cogateway.setup();
    await erc20Cogateway.setInboundChannelIdentifier(
      TestData.outboundChannelIdentifier,
    );
    await erc20Cogateway.setStorageRoot(
      TestData.blockNumber,
      TestData.rawProofResult.storageHash,
    );
  });

  it('should pass when deposit is confirmed.', async () => {
    const sender = accounts[2];
    await erc20Cogateway.confirmDeposit(
      param.valueToken,
      new BN(param.amount),
      param.beneficiary,
      new BN(param.feeGasPrice),
      new BN(param.feeGasLimit),
      param.depositor,
      param.blockNumber,
      param.rlpParentNodes,
      { from: sender },
    );

    const utilityTokenDeployedAddress = await erc20Cogateway
      .utilityTokens.call(
        param.valueToken,
      );
    const utilityTokenDeployed = await UtilityToken.at(utilityTokenDeployedAddress);

    const senderBalanceAfterConfirmDeposit = await utilityTokenDeployed
      .balanceOf(
        sender,
      );

    const beneficiaryBlanaceAfterConfirmDeposit = await utilityTokenDeployed
      .balanceOf(
        param.beneficiary,
      );

    const gasPrice = new BN(param.feeGasPrice);
    const gasLimit = new BN(param.feeGasLimit);
    const maxReward = gasPrice.mul(gasLimit);

    assert.strictEqual(
      maxReward.toString(10),
      senderBalanceAfterConfirmDeposit.toString(10),
      'Reward earned with sender must match with max reward.',
    );

    const amount = new BN(param.amount);
    const expectedAmountForBeneficiary = amount.sub(senderBalanceAfterConfirmDeposit);
    assert.strictEqual(
      expectedAmountForBeneficiary.toString(10),
      beneficiaryBlanaceAfterConfirmDeposit.toString(10),
      'Amount must be minted to beneficiary address and sender must get reward',
    );
  });
});
