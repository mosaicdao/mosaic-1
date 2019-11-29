// Copyright 2019 OpenST Ltd.
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

import shared, {ContractEntity, Validator} from '../shared';
import Utils, {ValidatorStatus} from "../Utils";
import {assert} from 'chai';
import BN = require("bn.js");
import {Reputation} from "../../interacts/Reputation";
import {Core} from "../../interacts/Core";

async function assertValidatorInReputation(
  reputation: ContractEntity<Reputation>,
  validator: Validator,
) {
  const validatorObject = await reputation.instance.methods.validators(validator.address).call();

  assert.isOk(
    new BN(validatorObject.status).eqn(ValidatorStatus.Staked),
    'Validator status must be staked',
  );
}

async function assertValidatorInCore(
  core: ContractEntity<Core>,
  validator: Validator,
) {
  const isValidator = await core.instance.methods.isValidator(validator.address).call;

  assert.isOk(
    isValidator,
    `Validator ${validator.address} must be registered to core`,
  );
}

describe('Consensus: Join during creation', async () => {
  it('Join during creation transaction', async () => {

    const consensus = shared.origin.contracts.Consensus;
    const reputation = shared.origin.contracts.Reputation;
    const core = shared.origin.contracts.Core;
    const validators = shared.origin.keys.validators;
    const mOST = shared.origin.contracts.MOST;
    const wETH = shared.origin.contracts.WETH;

    const mOSTSTakeAmount = await reputation.instance.methods.stakeMOSTAmount().call();
    const wETHSTakeAmount = await reputation.instance.methods.stakeWETHAmount().call();

    const approvalPromises = [];
    const joinDuringCreationPromises = [];

    validators.forEach((validator) => {

      // Approve most amount.
      approvalPromises.push(
        Utils.sendTransaction(
          mOST.instance.methods.approve(reputation.address, mOSTSTakeAmount),
          {from: validator.address},
        ),
      );

      // Approve WETH amount.
      approvalPromises.push(
        Utils.sendTransaction(
          wETH.instance.methods.approve(reputation.address, wETHSTakeAmount),
          {from: validator.address},
        ),
      );

      // Join during creation transaction.
      joinDuringCreationPromises.push(
        Utils.sendTransaction(
          consensus.instance.methods.joinDuringCreation(
            shared.origin.chainId,
            core.address,
            validator.withdrawalAddress,
          ),
          {
            from: validator.address
          },
        ),
      );
    });

    await Promise.all(approvalPromises);
    await Promise.all(joinDuringCreationPromises);

    validators.forEach(async (validator) => {
      await assertValidatorInReputation(reputation, validator);
      await assertValidatorInCore(core, validator);
    });
  });
});
