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
const ProveERC20GatewayProof = require('../../data/prove_erc20_gateway.json');
const Utils = require('../../test_lib/utils.js');

const ERC20Cogateway = artifacts.require('ERC20CogatewayDouble');
const SpyAnchor = artifacts.require('SpyAnchor');

contract('ERC20Cogateway::proveGateway', () => {
  let erc20Cogateway;

  const setupParams = {
    metachainId: Utils.getRandomHash(),
    outboxStorageIndex: new BN(1),
    maxStorageRootItems: new BN(100),
  };

  beforeEach(async () => {
    const spyAnchor = await SpyAnchor.new();
    erc20Cogateway = await ERC20Cogateway.new();

    await spyAnchor.anchorStateRoot(
      ProveERC20GatewayProof.blockNumber,
      ProveERC20GatewayProof.stateRoot,
    );

    // Sets genesis parameters.
    await erc20Cogateway.setupGenesis(
      setupParams.metachainId,
      ProveERC20GatewayProof.address,
      spyAnchor.address,
      setupParams.maxStorageRootItems,
      setupParams.outboxStorageIndex,
    );

    await erc20Cogateway.setup();
  });

  contract('Positive Tests', () => {
    it('should successfully prove ERC20Gateway contract address', async () => {
      const response = await erc20Cogateway.proveGateway(
        ProveERC20GatewayProof.blockNumber,
        ProveERC20GatewayProof.rlpAccountNode,
        ProveERC20GatewayProof.rlpParentNodes,
      );

      const actualStorageHash = await erc20Cogateway.storageRoots.call(
        ProveERC20GatewayProof.blockNumber,
      );

      assert.strictEqual(
        actualStorageHash,
        ProveERC20GatewayProof.storageHash,
        'Storage hash is incorrect.',
      );

      assert.isOk(
        response.receipt.logs.length > 0,
        'It must emit event.',
      );
      const eventObject = response.receipt.logs[0];

      assert.strictEqual(
        eventObject.event,
        'GatewayProven',
        'Must emit GatewayProven event.',
      );

      const expectedRemoteGateway = Utils.toChecksumAddress(ProveERC20GatewayProof.address);
      assert.strictEqual(
        eventObject.args.remoteGateway,
        expectedRemoteGateway,
        `Expected remote gateway address is ${expectedRemoteGateway} but got `
        + `${eventObject.args.remoteGateway}.`,
      );

      assert.isOk(
        eventObject.args.blockNumber.eqn(ProveERC20GatewayProof.blockNumber),
        `Expected block number is ${ProveERC20GatewayProof.blockNumber} but
        found to be ${eventObject.args.blockNumber.toString(10)}.`,
      );
    });
  });
});
