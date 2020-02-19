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
const Utils = require('../../test_lib/utils.js');
const ProveERC20CogatewayProof = require('../../data/prove_erc20_cogateway.json');

const ERC20Gateway = artifacts.require('ERC20Gateway');
const SpyAnchor = artifacts.require('SpyAnchor');

contract('ERC20Gateway::proveGateway', () => {
  let erc20Gateway;

  const setupParams = {
    metachainId: Utils.getRandomHash(),
    outboxStorageIndex: new BN(1),
    maxStorageRootItems: new BN(100),
  };

  beforeEach(async () => {
    const spyAnchor = await SpyAnchor.new();
    erc20Gateway = await ERC20Gateway.new();

    // Set state root.
    await spyAnchor.anchorStateRoot(
      ProveERC20CogatewayProof.blockNumber,
      ProveERC20CogatewayProof.stateRoot,
    );

    await erc20Gateway.setup(
      setupParams.metachainId,
      ProveERC20CogatewayProof.address,
      spyAnchor.address,
      setupParams.outboxStorageIndex,
      setupParams.maxStorageRootItems,
    );
  });

  contract('Positive Tests', () => {
    it('should successfully prove ERC20Cogateway contract address', async () => {
      const response = await erc20Gateway.proveGateway(
        ProveERC20CogatewayProof.blockNumber,
        ProveERC20CogatewayProof.rlpAccountNode,
        ProveERC20CogatewayProof.rlpParentNodes,
      );

      const actualStorageHash = await erc20Gateway.storageRoots.call(
        ProveERC20CogatewayProof.blockNumber,
      );

      assert.strictEqual(
        actualStorageHash,
        ProveERC20CogatewayProof.storageHash,
        'Storage hash is incorrect.',
      );

      assert.isOk(
        response.receipt.logs.length > 0,
        'It must emit event',
      );
      const eventObject = response.receipt.logs[0];

      assert.strictEqual(
        eventObject.event,
        'GatewayProven',
        'Must emit GatewayProven event',
      );

      assert.strictEqual(
        eventObject.args.gateway,
        erc20Gateway.address,
        'Gateway address is incorrect in the event.',
      );

      assert.isOk(
        eventObject.args.blockNumber.eqn(ProveERC20CogatewayProof.blockNumber),
        'Block number is incorrect in the event.',
      );
    });
  });
});
