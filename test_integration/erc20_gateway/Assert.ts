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
const assert = require('assert');

import Interacts from '../../interacts/Interacts';
import shared from './shared';

/**
 * It has methods used in assertion of ERC20Gateway's integration tests.
 */
export default class Assert {

  /**
   * Assertion for GatewayProven event.
   *
   * @param event GatewayProven event.
   * @param expectedInboxAddress Expected Inbox address.
   * @param expectedBlockNumber Expected block number.
   */
  public static assertGatewayProven(
    event: {returnValues: {}},
    expectedInboxAddress: string,
    expectedBlockNumber: BN,
  ) : void {
    assert.strictEqual(
      event.returnValues['remoteGateway'],
      expectedInboxAddress,
      'Incorrect remote gateway address',
    );

    assert.strictEqual(
      expectedBlockNumber.eq(new BN(event.returnValues['blockNumber'])),
      true,
      `Expected block number for gateway proven is ${expectedBlockNumber.toString(10)}`
      + ` but got ${event.returnValues['blockNumber']} `,
    );
  }

  /**
   * Assertion for StateRootAvailable event.
   *
   * @param event StateRootAvailable event.
   * @param blockNumber Block number at which anchoring is done.
   * @param stateRoot State root for a block.
   */
  public static assertAnchor(
    event: { returnValues: {} },
    blockNumber: BN,
    stateRoot: string,
  ) : void {
    assert.strictEqual(
      blockNumber.eq(new BN(event.returnValues['_blockNumber'])),
      true,
      `Expected blocknumber at which anchoring is done ${blockNumber.toString(10)} but got`
      + `${event.returnValues['_blockNumber']}`,
    );

    assert.strictEqual(
      event.returnValues['_stateRoot'],
      stateRoot,
      'Incorrect state root',
    );
  }

  /**
   * It asserts minting of utility tokens.
   *
   * @param facilitatorAddress Address of facilitator who did confirm deposit transaction.
   * @param feeGasLimit Gas limit which the depositor is ready to pay for deposit.
   * @param feeGasPrice Gas price which the depositor is ready to pay for deposit.
   * @param utilityToken Utility token address.
   * @param beneficiary Beneficiary address who gets minted utility tokens.
   * @param depositAmount Amount deposited by depositor.
   */
  public static async assertMinting(
    facilitatorAddress: string,
    feeGasLimit: BN,
    feeGasPrice: BN,
    utilityToken: string,
    beneficiary: string,
    depositAmount: BN,
  ): Promise<void> {
    const utilityTokenInstance = Interacts.getUtilityToken(shared.web3, utilityToken);

    const actualBeneficiaryBalance = new BN(
      await utilityTokenInstance.methods.balanceOf(beneficiary).call(),
    );

    const facilitatorBalance = new BN(
      await utilityTokenInstance.methods.balanceOf(facilitatorAddress).call(),
    );

    const reward = feeGasPrice.mul(feeGasLimit);
    const mintedAmount = depositAmount.sub(reward);

    assert.strictEqual(
      actualBeneficiaryBalance.eq(mintedAmount),
      true,
      `Expected beneficiary balance is ${mintedAmount.toString(10)} `
       + `but got ${mintedAmount.toString(10)}`,
    );

    assert.strictEqual(
      facilitatorBalance.eq(reward),
      true,
      `Expected facilitator balance is ${reward.toString(10)} `
      + `but got ${facilitatorBalance.toString(10)}`,
    );
  }

  /**
   * It asserts message hash received for DepositIntentConfirmed event.
   *
   * @param actualMessageHash Message hash from the event.
   * @param expectedMessageHash Expected message hash.
   */
  public static assertDepositIntentConfirmed(
    actualMessageHash: string,
    expectedMessageHash: string,
  ) : void {
    assert.strictEqual(
      actualMessageHash,
      expectedMessageHash,
      'Invalid deposit intent message hash',
    );
  }

  /**
   * It asserts balances after deposit is done.
   *
   * @param depositorBalanceBeforeDeposit Depositor's value token balance before deposit.
   * @param depositorBalanceAfterDeposit Depositor's value token balance after deposit.
   * @param erc20ContractBalanceBeforeTransfer ERC20Contract's value token balance before deposit.
   * @param erc20GatewayAfterBalance ERC20Contract's value token balance after deposit.
   * @param depositedAmount Amount deposited by depositor.
   */
  public static assertDeposit(
    depositorBalanceBeforeDeposit: BN,
    depositorBalanceAfterDeposit: BN,
    erc20ContractBalanceBeforeTransfer: BN,
    erc20GatewayAfterBalance: BN,
    depositedAmount: BN,
  ) : void{
    assert.strictEqual(
      depositorBalanceBeforeDeposit.sub(depositedAmount).eq(depositorBalanceAfterDeposit),
      true,
      'Expected depositor balance is'
      + `${(depositorBalanceBeforeDeposit.sub(depositedAmount)).toString(10)}`
      + `but got ${depositorBalanceAfterDeposit.toString(10)}`,
    );

    assert.strictEqual(
      erc20ContractBalanceBeforeTransfer.add(depositedAmount).eq(erc20GatewayAfterBalance),
      true,
      'Expected erc20Gateway balance is '
      +`${(erc20ContractBalanceBeforeTransfer.add(depositedAmount)).toString(10)} `
      + `but got ${erc20GatewayAfterBalance.toString(10)}`,
    );
  }

  /**
   * It asserts the parameters in the `GenesisERC20Cogateway` contract with params provided
   * at the time of ERC20Gateway setup.
   *
   * @param params ERC20Cogateway setup parameters.
   * @param genesisMetachainId Value of genesisMetachainId storage in
   *                           `GenesisERC20Cogateway` contract.
   * @param genesisERC20Gateway Value of genesisERC20Gateway storage in
   *                            `GenesisERC20Cogateway` contract.
   * @param genesisStateRootProvider Value of genesisERC20Gateway in
   *                                 `GenesisERC20Cogateway` contract.
   * @param genesisMaxStorageRootItems Value of genesisERC20Gateway storage in
   *                                   `GenesisERC20Cogateway` contract.
   * @param genesisOutboxStorageIndex Value of genesisOutboxStorageIndex in
   *                                  `GenesisERC20Cogateway` contract.
   * @param genesisUtilityTokenMastercopy Value of `genesisUtilityTokenMastercopy` storage in
   *                                      `GenesisERC20Cogateway` contract.
   */
  public static assertERC20CogatewaySetup(
    params: any,
    genesisMetachainId: string,
    genesisERC20Gateway: string,
    genesisStateRootProvider: string,
    genesisMaxStorageRootItems: BN,
    genesisOutboxStorageIndex: BN,
    genesisUtilityTokenMastercopy: string,
  ): void {
    assert.strictEqual(
      params.metachainId,
      genesisMetachainId,
      'Incorrect genesis metachain id',
    );

    assert.strictEqual(
      params.erc20Gateway,
      genesisERC20Gateway,
      'Incorrect genesis ERC20gateway contract address',
    );

    assert.strictEqual(
      params.stateRootProvider,
      genesisStateRootProvider,
      'Incorrect genesis state root provider contract address',
    );

    assert.strictEqual(
      params.utilityTokenMasterCopy,
      genesisUtilityTokenMastercopy,
      'Incorrect genesis utility token master copy  contract address',
    );

    assert.strictEqual(
      params.maxStorageRootItems.eq(genesisMaxStorageRootItems),
      true,
      `Expected genesis max storage root items is ${params.maxStorageRootItems.toString(10)} `
      + `but got ${genesisMaxStorageRootItems.toString(10)}`,
    );

    assert.strictEqual(
      genesisOutboxStorageIndex.eq(new BN(params.coGatewayOutboxIndex)),
      true,
      `Expected genesis outbox storage index is ${params.coGatewayOutboxIndex} `
      + `but got ${genesisOutboxStorageIndex.toString(10)}`,
    );
  }

  /**
   *
   * @param actualConsensusAddress
   * @param expectedConsensusAddress
   */
  public static assertAnchorSetup(
    actualConsensusAddress: string,
    expectedConsensusAddress: string,
  ) : void {
    assert.strictEqual(
      actualConsensusAddress,
      expectedConsensusAddress,
      'Incorrect consensus address in Anchor setup',
    );
  }

  /**
   * It asserts ERC20Gateway storage with the params provided during setup of it.
   *
   * @param params ERC20Gateway setup params.
   * @param messageInbox Message inbox contract address in ERC20Gateway contract.
   * @param stateRootProvider State root provider address in ERC20Gateway contract.
   * @param outboxStorageIndex Outbox storage index value in ERC20Gateway contract.
   */
  public static assertERC20GatewaySetup(
    params: any,
    messageInbox: string,
    stateRootProvider: string,
    outboxStorageIndex: BN,
  ) {
    assert.strictEqual(
      messageInbox,
      params.erc20Cogateway,
      'Incorrect message inbox contract address',
    );

    assert.strictEqual(
      stateRootProvider,
      params.stateRootProvider,
      'Incorrect state root provider contract address',
    );

    assert.strictEqual(
      outboxStorageIndex.eq(new BN(params.gatewayOutboxIndex)),
      true,
      `Expected outbox storage index is ${params.gatewayOutboxIndex} `
      + `but got ${outboxStorageIndex.toString(10)}`,
    );
  }
}
