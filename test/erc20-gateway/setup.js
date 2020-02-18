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

const ERC20Cogateway = artifacts.require('ERC20CogatewayDouble');
const BN = require('bn.js');
const Utils = require('../test_lib/utils.js');
const { AccountProvider } = require('../test_lib/utils.js');

contract('ERC20Gateway::setup', (accounts) => {
  const accountProvider = new AccountProvider(accounts);
  let erc20Cogateway;
  let setupGenesisParams = {};

  beforeEach(async () => {
    erc20Cogateway = await ERC20Cogateway.new();
    setupGenesisParams = {
      genesisMetachainId: Utils.generateRandomMetachainId(),
      genesisERC20Gateway: accountProvider.get(),
      genesisStateRootProvider: accountProvider.get(),
      genesisMaxStorageRootItems: new BN(100),
      genesisOutboxStorageIndex: new BN(4),
    };
    await erc20Cogateway.setupGenesis(
      setupGenesisParams.genesisMetachainId,
      setupGenesisParams.genesisERC20Gateway,
      setupGenesisParams.genesisStateRootProvider,
      setupGenesisParams.genesisMaxStorageRootItems,
      setupGenesisParams.genesisOutboxStorageIndex,
    );
  });

  it('should successfully setup ERC20 gateway contract', async () => {

    await erc20Cogateway.setup();

    const messageInboxInContract = await erc20Cogateway.messageInbox.call();

  });
});
