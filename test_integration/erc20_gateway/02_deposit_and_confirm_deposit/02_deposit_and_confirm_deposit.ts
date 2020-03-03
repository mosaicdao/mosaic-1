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
const assert = require('assert');
const BN = require('bn.js');
import Utils from '../Utils';
import { ERC20I } from '../../../interacts/ERC20I';
import { ERC20Gateway } from '../../../interacts/ERC20Gateway';
import { ERC20Cogateway } from '../../../interacts/ERC20Cogateway';
import Assert from '../Assert';

describe('Deposit and Confirm Deposit', async (): Promise<void> => {

  let depositParam;
  let valueToken: ERC20I;
  let erc20Gateway: ContractEntity<ERC20Gateway>;
  let erc20Cogateway: ContractEntity<ERC20Cogateway>;
  let depositMessageHash: string;
  let blockNumber;
  before(async (): Promise<void> => {
    erc20Gateway = shared.contracts.ERC20Gateway;
    erc20Cogateway = shared.contracts.ERC20Cogateway;
    valueToken = shared.contracts.ValueToken.instance;

    depositParam = {
      amount: new BN(100),
      beneficiary: shared.accounts[7],
      feeGasPrice: new BN(1),
      feeGasLimit: new BN(10),
      valueToken: shared.contracts.ValueToken.address,
      depositor: shared.depositor,
    }
  });

  it('should deposit successfully', async (): Promise<void> => {
    const approveTx = valueToken.methods.approve(
      erc20Gateway.address,
      depositParam.amount,
    )

    await Utils.sendTransaction(
      approveTx,
      {
        from: depositParam.depositor,
      }
    );

    const depositorBalanceBeforeTransfer = new BN(
      await valueToken.methods.balanceOf(depositParam.depositor).call(),
    );
    const erc20ContractBalanceBeforeTransfer = new BN(
      await valueToken.methods.balanceOf(erc20Gateway.address).call(),
    );

    console.log(" Before Depositor Balance ===>>", depositorBalanceBeforeTransfer);
    console.log("Before Gateway Balance ==>", erc20ContractBalanceBeforeTransfer);

    const rawTx = erc20Gateway.instance.methods.deposit(
      depositParam.amount,
      depositParam.beneficiary,
      depositParam.feeGasPrice,
      depositParam.feeGasLimit,
      depositParam.valueToken,
    );

    const tx = await Utils.sendTransaction(
      rawTx,
      {
        from: depositParam.depositor,
      }
    );

    depositMessageHash = tx.events.DepositIntentDeclared.returnValues['messageHash'];

    const depositorBalanceAfterTransfer = new BN(
      await valueToken.methods.balanceOf(depositParam.depositor).call(),
    );
    const erc20ContractBalanceAfterTransfer = new BN(
      await valueToken.methods.balanceOf(erc20Gateway.address).call(),
    );

    console.log("After Depositor Balance ==> ", depositorBalanceAfterTransfer);
    console.log("After Gateway bal===>", erc20ContractBalanceAfterTransfer);

    assert.strictEqual(
      depositorBalanceBeforeTransfer.sub(depositParam.amount).eq(depositorBalanceAfterTransfer),
      true,
      `Expected depositor balance is ${depositorBalanceBeforeTransfer.sub(depositParam.amount)}`
      + `but got ${depositorBalanceAfterTransfer}`
    );

    assert.strictEqual(
      erc20ContractBalanceBeforeTransfer.add(depositParam.amount).eq(erc20ContractBalanceAfterTransfer),
      true,
      `Expected depositor balance is ${erc20ContractBalanceBeforeTransfer.add(depositParam.amount)}`
      + `but got ${erc20ContractBalanceAfterTransfer}`
    );
  });

  it('should anchor successfully',async (): Promise<void> => {
    const auxiliaryAnchor = shared.contracts.AuxilaryAnchor.instance;
    const block = await Utils.getBlock('latest');
    blockNumber = new BN(block.number);
    const rawTx = auxiliaryAnchor.methods.anchorStateRoot(
      blockNumber,
      block.stateRoot,
    );

    const tx = await Utils.sendTransaction(
      rawTx,
      {
        from: shared.coconsensus,
      }
    );

    // console.log('tx : ', tx);
    const event = tx.events.StateRootAvailable;

    // assert.strictEqual(
    //   blockNumber.eq(new BN(event.returnValues['_blockNumber'])),
    //   true,
    //   `Expected blocknumber at which anchoring is done ${blockNumber.toString(10)} but got`
    //   + `${event.returnValues['_blockNumber']}`,
    // );

    // assert.strictEqual(
    //   event.returnValues['_stateRoot'],
    //   block.stateRoot,
    //   'Incorrect state root',
    // );

    Assert.assertAnchor(
      tx.events.StateRootAvailable,
      blockNumber,
      block.stateRoot,
    );

  });

  it('should prove ERC20Gateway contract',async(): Promise<void> => {
    const proof = await Utils.getAccountProof(
      erc20Gateway.address,
      blockNumber,
    );

    const rawTx = erc20Cogateway.instance.methods.proveGateway(
      blockNumber,
      proof.encodedAccountValue,
      proof.serializedProof,
    );

    const tx = await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      }
    );

    Assert.assertGatewayProven(
      tx.events.GatewayProven,
      erc20Gateway.address,
      new BN(blockNumber),
    );
  });

  it('should confirm deposit successfully', async (): Promise<void> => {
    const outboxStorageIndex = await erc20Cogateway.instance.methods.outboxStorageIndex().call();
    const storagePath = await Utils.storagePath(outboxStorageIndex, [depositMessageHash]);

    const proofData = await Utils.getProof(
      shared.contracts.ERC20Gateway.address,
      [storagePath],
      blockNumber.toString(10),
    );

    const serializedStorageProof = Utils.formatProof(proofData.storageProof[0].proof);

    const rawTx = erc20Cogateway.instance.methods.confirmDeposit(
      shared.contracts.ValueToken.address,
      depositParam.amount,
      depositParam.beneficiary,
      depositParam.feeGasPrice,
      depositParam.feeGasLimit,
      depositParam.depositor,
      blockNumber.toString(10),
      serializedStorageProof as any,
    );

    await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      }
    );
  });
});
