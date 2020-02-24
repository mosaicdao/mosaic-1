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

'use strict';

const BN = require('bn.js');
const { AccountProvider } = require('../../test_lib/utils.js');
const Utils = require('../../test_lib/utils.js');
const TestData = require('../../consensus-gateway/data/erc20_deposit_proof');

const ERC20Cogateway = artifacts.require('ERC20CogatewayDouble');
const UtilityToken = artifacts.require('UtilityToken');

contract('ERC20Cogateway::confirmDeposit', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let erc20Cogateway;
  let setupGenesisParams = {};
  let tokenSetup = {};
  let valueToken;

  beforeEach(async () => {
    erc20Cogateway = await ERC20Cogateway.new();

    valueToken = await UtilityToken.new();

    tokenSetup = {
      TOKEN_SYMBOL: 'UT',
      TOKEN_NAME: 'Utility Token',
      TOTAL_TOKEN_SUPPLY: new BN('1000'),
      TOKEN_DECIMALS: 18,
      Cogateway: erc20Cogateway.address,
      valueTokenContract: valueToken.address,
    };

    await valueToken.setup(
      tokenSetup.TOKEN_SYMBOL,
      tokenSetup.TOKEN_NAME,
      tokenSetup.TOKEN_DECIMALS,
      tokenSetup.TOTAL_TOKEN_SUPPLY,
      tokenSetup.Cogateway,
      tokenSetup.valueTokenContract,
    );

    setupGenesisParams = {
      genesisMetachainId: Utils.generateRandomMetachainId(),
      genesisERC20Gateway: accountProvider.get(),
      genesisStateRootProvider: accountProvider.get(),
      genesisMaxStorageRootItems: new BN(100),
      genesisOutboxStorageIndex: new BN(4),
      genesisUtilityTokenMasterCopy: valueToken.address,
    };

    await erc20Cogateway.setupGenesis(
      setupGenesisParams.genesisMetachainId,
      setupGenesisParams.genesisERC20Gateway,
      setupGenesisParams.genesisStateRootProvider,
      setupGenesisParams.genesisMaxStorageRootItems,
      setupGenesisParams.genesisOutboxStorageIndex,
      setupGenesisParams.genesisUtilityTokenMasterCopy,
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

  contract('Positive Tests', () => {
    it('should successfully confirm deposit', async () => {});
  });
});
