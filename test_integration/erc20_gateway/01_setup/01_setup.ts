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

import shared, { ContractEntity } from '../shared';
import Utils from '../Utils';
import { ERC20Gateway } from '../../../interacts/ERC20Gateway';
import { ERC20Cogateway } from '../../../interacts/ERC20Cogateway';
import Assert from '../Assert';

const BN = require('bn.js');

describe('Contract Setup', async (): Promise<void> => {

  let ERC20Gateway: ContractEntity<ERC20Gateway>;
  let ERC20Cogateway: ContractEntity<ERC20Cogateway>;

  before(async() => {
    ERC20Gateway = shared.contracts.ERC20Gateway;
    ERC20Cogateway = shared.contracts.ERC20Cogateway;

    shared.metachainId = shared.web3.utils.randomHex(32);
    const utilityTokenMasterCopy = await shared.artifacts.UtilityToken.new();
    shared.utilityTokenMasterCopy = utilityTokenMasterCopy.address;
    shared.consensus = shared.accounts[4];
    shared.coconsensus = shared.accounts[9];
  });

  it('should setup Anchor', async (): Promise<void> => {
    const originAnchor = shared.contracts.OriginAnchor.instance;
    const originAnchorRawTx = originAnchor.methods.setup(
      new BN(100),
      shared.consensus,
    );

    await Utils.sendTransaction(
      originAnchorRawTx,
      {
        from: shared.accounts[7],
      }
    );

    const auxAnchor = shared.contracts.AuxilaryAnchor.instance;
    const rawTx = auxAnchor.methods.setup(
      new BN(100),
      shared.coconsensus,
    );

    await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      }
    );
  });

  it('should setup ERC20Gateway', async (): Promise<void> => {
    const erc20Gateway = ERC20Gateway.instance;

    const params = {
      metachainId: shared.metachainId,
      erc20Cogateway: ERC20Cogateway.address,
      stateRootProvider: shared.contracts.OriginAnchor.address,
      maxStorageRootItems: new BN(50),
      gatewayOutboxIndex: await ERC20Cogateway.instance.methods.OUTBOX_OFFSET().call(),
    };

    const rawTx = erc20Gateway.methods.setup(
      params.metachainId,
      params.erc20Cogateway,
      params.stateRootProvider,
      params.maxStorageRootItems,
      params.gatewayOutboxIndex.toString(),
    );

    await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      }
    );
  });

  it('should activate ERC20Cogateway contract', async (): Promise<void> => {
    const erc20Cogateway = shared.contracts.ERC20Cogateway.instance;

    const params = {
      metachainId: shared.metachainId,
      erc20Gateway: shared.contracts.ERC20Gateway.address,
      stateRootProvider: shared.contracts.AuxilaryAnchor.address,
      maxStorageRootItems: new BN(50),
      coGatewayOutboxIndex: await shared.contracts.ERC20Gateway.instance.methods.OUTBOX_OFFSET().call(),
      utilityTokenMasterCopy: shared.utilityTokenMasterCopy,
    };

    const rawTx = erc20Cogateway.methods.activate(
      params.metachainId,
      params.erc20Gateway,
      params.stateRootProvider,
      params.maxStorageRootItems,
      params.coGatewayOutboxIndex.toString(),
      params.utilityTokenMasterCopy,
    );

    await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      }
    );

    Assert.assertERC20CogatewaySetup(
      params,
      await erc20Cogateway.methods.genesisMetachainId().call(),
      await erc20Cogateway.methods.genesisERC20Gateway().call(),
      await erc20Cogateway.methods.genesisStateRootProvider().call(),
      new BN(await erc20Cogateway.methods.genesisMaxStorageRootItems().call()),
      new BN(await erc20Cogateway.methods.genesisOutboxStorageIndex().call()),
      await erc20Cogateway.methods.genesisUtilityTokenMastercopy().call(),
    );
  });
});
