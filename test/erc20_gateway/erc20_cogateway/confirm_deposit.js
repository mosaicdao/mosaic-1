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

'use-strict';

const BN = require('bn.js');
const { AccountProvider } = require('../../test_lib/utils.js');

const TestData = require('../../../test/erc20_gateway/data/erc20_deposit_proof.json');

const UtilityToken = artifacts.require('UtilityToken');

const ERC20Cogateway = artifacts.require('ERC20CogatewayDouble');

contract('ERC20Cogateway::confirmDeposit', async (accounts) => {
  // const accountProvider = new AccountProvider(accounts);
  let erc20Cogateway;
  let setupGenesisParams;
  let utilityToken;
  let param = {};

  beforeEach(async () => {
    erc20Cogateway = await ERC20Cogateway.new();

    utilityToken = await UtilityToken.new();
    console.log('address UT  ', utilityToken.address);

    // console.log('utilityToken :-', utilityToken);

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
    const messageHash = await erc20Cogateway.confirmDeposit.call(
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

    console.log('Message Hash :-', messageHash);
  });
});
