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

import shared from "../shared";
import Utils from '../Utils';
import Assert from "../Assert";
import Interacts from "../../../interacts/Interacts";

describe('withdraw and confirm withdraw', async (): Promise<void> => {

  let erc20Cogateway;
  let erc20Gateway;
  let blockNumber: BN;
  let beneficiaryAtAuxiliary;
  let beneficiaryAtOrigin;
  let utilityToken: string;
  let withdrawMessageHash: string;
  let withdrawParams: { withdrawalAmount: any; beneficiary: string; feeGasPrice: BN; feeGasLimit: BN; utilityToken: string; };

  before(() => {
    erc20Cogateway = shared.contracts.ERC20Cogateway;
    erc20Gateway = shared.contracts.ERC20Gateway;
    beneficiaryAtAuxiliary = shared.accounts[7];
    beneficiaryAtOrigin = shared.accounts[11];
  });

  it('should withdraw successfully', async (): Promise<void> => {
    utilityToken = await erc20Cogateway.instance.methods.utilityTokens(
      shared.contracts.ValueToken.address,
    ).call();
    const utilityTokenInstance = Interacts.getUtilityToken(shared.web3, utilityToken);

    const rawTx = utilityTokenInstance.methods.approve(
      erc20Cogateway.address,
      '40',
    );

    const withdrawerAddress = beneficiaryAtAuxiliary;

    await Utils.sendTransaction(
      rawTx,
      {
        from: withdrawerAddress,
      }
    );

    withdrawParams = {
      withdrawalAmount: new BN(40),
      beneficiary: beneficiaryAtOrigin,
      feeGasPrice: new BN(2),
      feeGasLimit: new BN(10),
      utilityToken: utilityToken,
    };

    const withdrawerBalanceBeforeWithdraw = await utilityTokenInstance.methods.balanceOf(
      withdrawerAddress,
    ).call();

    const withdrawRawTx = erc20Cogateway.instance.methods.withdraw(
      withdrawParams.withdrawalAmount.toString(10),
      withdrawParams.beneficiary,
      withdrawParams.feeGasPrice.toString(10),
      withdrawParams.feeGasLimit.toString(10),
      withdrawParams.utilityToken,
    );

    const tx = await Utils.sendTransaction(
      withdrawRawTx,
      {
        from: withdrawerAddress,
      }
    );

    withdrawMessageHash = tx.events.WithdrawIntentDeclared.returnValues['messageHash'];

    const withdrawerBalanceAfterWithdraw = await utilityTokenInstance.methods.balanceOf(
      withdrawerAddress,
    ).call();

    await Assert.assertWithdrawIntentDeclared(
      tx.events.WithdrawIntentDeclared,
      withdrawerAddress,
      withdrawParams,
    );

    Assert.assertWithdraw(
      new BN(withdrawerBalanceBeforeWithdraw),
      new BN(withdrawerBalanceAfterWithdraw),
      withdrawParams.withdrawalAmount,
    );
  });

  it('should anchor auxiliary stateroot on origin', async (): Promise<void> => {
    const anchor = await Utils.performAnchor(
      shared.contracts.OriginAnchor.instance,
      shared.consensus,
    );

    Assert.assertAnchor(
      anchor.tx.events.StateRootAvailable,
      anchor.blockNumber,
      anchor.stateRoot,
    );

    blockNumber = anchor.blockNumber;
  });

  it('should prove ERC20Cogateway successfully', async(): Promise<void> => {
    const proof = await Utils.getAccountProof(
      erc20Cogateway.address,
      blockNumber.toString(10),
    );

    const rawTx = erc20Gateway.instance.methods.proveGateway(
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
      erc20Cogateway.address,
      new BN(blockNumber),
    );
  });

  it('should confirm withdraw successfully', async (): Promise<void> => {
    const outboxStorageIndex = await erc20Gateway.instance.methods.outboxStorageIndex().call();
    const storagePath = Utils.storagePath(outboxStorageIndex, [withdrawMessageHash]);

    const serializedStorageProof = await Utils.getStorageProof(
      erc20Cogateway.address,
      [storagePath],
      blockNumber.toString(10),
    );

    const facilitatorBalanceBeforeConfirmWithdraw = await shared.contracts.ValueToken.instance.methods.
      balanceOf(shared.facilitator).call();

    const beneficiaryBalanceBeforeConfirmWithdraw = await shared.contracts.ValueToken.instance.methods.
      balanceOf(withdrawParams.beneficiary).call();

    const rawTx = erc20Gateway.instance.methods.confirmWithdraw(
      utilityToken,
      shared.contracts.ValueToken.address,
      withdrawParams.withdrawalAmount,
      withdrawParams.beneficiary,
      withdrawParams.feeGasPrice.toString(),
      withdrawParams.feeGasLimit.toString(),
      beneficiaryAtAuxiliary, // withdrawer address
      blockNumber.toString(10),
      serializedStorageProof as any,
    );

    const tx = await Utils.sendTransaction(
      rawTx,
      {
        from: shared.facilitator,
      },
    );

    Assert.assertWithdrawIntentConfirmed(
      tx.events.WithdrawIntentConfirmed.returnValues['messageHash'],
      withdrawMessageHash,
    );

    await Assert.assertConfirmWithdraw(
      shared.facilitator,
      withdrawParams.feeGasLimit,
      withdrawParams.feeGasPrice,
      shared.contracts.ValueToken,
      withdrawParams.beneficiary,
      withdrawParams.withdrawalAmount,
      new BN(facilitatorBalanceBeforeConfirmWithdraw),
      new BN(beneficiaryBalanceBeforeConfirmWithdraw),
    );
  });
});
