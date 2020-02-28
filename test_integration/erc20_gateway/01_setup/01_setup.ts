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

import shared from '../shared';

const BN = require('bn.js');

describe('Contract Setup', async () => {

  beforeEach(async() => {
    shared.metachainId = shared.web3.utils.randomHex(32);
    shared.utilityTokenMasterCopy = shared.accounts[6];
  });

  it('should setup Anchor', async () => {

    let consensus = shared.accounts[4];
    const originAnchor = shared.contracts.OriginAnchor.instance;
    originAnchor.methods.setup(
      new BN(100),
      consensus,
    );

    let coconsensus = shared.accounts[5];
    const auxAnchor = shared.contracts.AuxilaryAnchor.instance;
    auxAnchor.methods.setup(
      new BN(100),
      coconsensus,
    );
  });

  it('should setup ERC20Gateway', async () => {

    const ERC20Gateway = shared.contracts.ERC20Gateway.instance;

    const params = {
      metachainId: shared.metachainId,
      erc20Cogateway: shared.contracts.ERC20Cogateway.address,
      stateRootProvider: shared.contracts.OriginAnchor.address,
      maxStorageRootItems: new BN(50),
      gatewayOutboxIndex: ERC20Gateway.methods.OUTBOX_OFFSET(),
    };

    ERC20Gateway.methods.setup(
      params.metachainId,
      params.erc20Cogateway,
      params.stateRootProvider,
      params.maxStorageRootItems,
      params.gatewayOutboxIndex.toString(),
    );
  });

  it('should activates ERC20Cogateway', async () => {

    const ERC20Cogateway = shared.contracts.ERC20Cogateway.instance;

    const params = {
      metachainId: shared.metachainId,
      erc20Gateway: shared.contracts.ERC20Gateway.address,
      stateRootProvider: shared.contracts.AuxilaryAnchor.address,
      maxStorageRootItems: new BN(50),
      coGatewayOutboxIndex: ERC20Cogateway.methods.OUTBOX_OFFSET(),
      utilityTokenMastercopy: shared.utilityTokenMasterCopy,
    };

    ERC20Cogateway.methods.activate(
      params.metachainId,
      params.erc20Gateway,
      params.stateRootProvider,
      params.maxStorageRootItems,
      params.coGatewayOutboxIndex.toString(),
      params.utilityTokenMastercopy,
    );
  });
});