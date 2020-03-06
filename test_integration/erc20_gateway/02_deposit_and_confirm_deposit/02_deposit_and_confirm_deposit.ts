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

import BN from 'bn.js';

import shared, { ContractEntity } from '../shared';
import Utils from '../Utils';
import { ERC20I } from '../../../interacts/ERC20I';
import { ERC20Gateway } from '../../../interacts/ERC20Gateway';
import { ERC20Cogateway } from '../../../interacts/ERC20Cogateway';
import Assert from '../Assert';

describe('Deposit and Confirm Deposit', async (): Promise<void> => {
  let depositParam = {
    amount: new BN(100),
    depositor: '',
    beneficiary: '',
    feeGasPrice: new BN(2),
    feeGasLimit: new BN(10),
    valueToken: '',
  };
  let valueToken: ERC20I;
  let erc20Gateway: ContractEntity<ERC20Gateway>;
  let erc20Cogateway: ContractEntity<ERC20Cogateway>;
  let depositMessageHash: string;
  let blockNumber: BN;

  before(async (): Promise<void> => {
    erc20Gateway = shared.contracts.ERC20Gateway;
    erc20Cogateway = shared.contracts.ERC20Cogateway;
    valueToken = shared.contracts.ValueToken.instance;
    depositParam.valueToken = shared.contracts.ValueToken.address;
    depositParam.beneficiary = shared.accounts[7];
    depositParam.depositor = shared.depositor;
  });

  it('should deposit successfully', async (): Promise<void> => {
    const approveTx = valueToken.methods.approve(
      erc20Gateway.address,
      depositParam.amount.toString(10),
    );

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

    const rawTx = erc20Gateway.instance.methods.deposit(
      depositParam.amount.toString(10),
      depositParam.beneficiary,
      depositParam.feeGasPrice.toString(10),
      depositParam.feeGasLimit.toString(10),
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

    Assert.assertDeposit(
      depositorBalanceBeforeTransfer,
      depositorBalanceAfterTransfer,
      erc20ContractBalanceBeforeTransfer,
      erc20ContractBalanceAfterTransfer,
      depositParam.amount,
    );
  });

  it('should anchor at auxiliary successfully',async (): Promise<void> => {
    const anchor = await Utils.performAnchor(
      shared.contracts.AuxilaryAnchor.instance,
      shared.coconsensus,
    );

    Assert.assertAnchor(
      anchor.tx.events.StateRootAvailable,
      anchor.blockNumber,
      anchor.stateRoot,
    );

    blockNumber = anchor.blockNumber;
  });

  it('should prove ERC20Gateway contract',async(): Promise<void> => {
    const proof = await Utils.getAccountProof(
      erc20Gateway.address,
      blockNumber.toString(10),
    );

    const rawTx = erc20Cogateway.instance.methods.proveGateway(
      blockNumber.toString(10),
      // @ts-ignore
      proof.encodedAccountValue,
      // @ts-ignore
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
    const storagePath = Utils.storagePath(outboxStorageIndex, [depositMessageHash]);
    const serializedStorageProof = await Utils.getStorageProof(
      shared.contracts.ERC20Gateway.address,
      [storagePath],
      blockNumber.toString(10),
    );

    const rawTx = erc20Cogateway.instance.methods.confirmDeposit(
      depositParam.valueToken,
      depositParam.amount.toString(10),
      depositParam.beneficiary,
      depositParam.feeGasPrice.toString(10),
      depositParam.feeGasLimit.toString(10),
      depositParam.depositor,
      blockNumber.toString(10),
      serializedStorageProof as any,
    );

    const tx = await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      },
    );

    Assert.assertDepositIntentConfirmed(
      tx.events.DepositIntentConfirmed.returnValues['messageHash'],
      depositMessageHash,
    );

    const utilityToken = await erc20Cogateway.instance.methods.utilityTokens(
      depositParam.valueToken,
    ).call();

    await Assert.assertMinting(
      shared.facilitator,
      depositParam.feeGasLimit,
      depositParam.feeGasPrice,
      utilityToken,
      depositParam.beneficiary,
      depositParam.amount,
    );

    shared.beneficiaryAtAuxiliary = depositParam.beneficiary;
  });
});
