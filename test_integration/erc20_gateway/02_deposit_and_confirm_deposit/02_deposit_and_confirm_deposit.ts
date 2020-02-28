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
import EventDecoder from '../event_decoder';

describe('Deposit and Confirm Deposit', async () => {

  let depositParam;
  let valueToken;
  let ERC20Gateway;
  let ERC20Cogateway;
  let depositMessageHash;
  let gasPrice;
  let blockNumber;
  let storageProof;

  before(async () => {
    ERC20Gateway = shared.contracts.ERC20Gateway;
    ERC20Cogateway = shared.contracts.ERC20Cogateway;
    valueToken = shared.contracts.ValueToken.instance;
    gasPrice = "0x01"

    depositParam = {
      amount: new BN(100),
      beneficiary: shared.accounts[7],
      feeGasPrice: new BN(1),
      feeGasLimit: new BN(10),
      valueToken: shared.contracts.ValueToken.address, 
      depositor: shared.depositor,
    }
  });

  it('Deposit', async () => {
    
    await valueToken.methods.approve(
      ERC20Gateway.address,
      depositParam.amount,
    ).send(
      { from: depositParam.depositor },
    );

    const depositorBalanceBeforeTransfer = await valueToken.methods.balanceOf(depositParam.depositor).call();
    const erc20ContractBalanceBeforeTransfer = await valueToken.methods.balanceOf(ERC20Gateway.address).call();

    console.log(" Before Depositor Balance ===>>", depositorBalanceBeforeTransfer);
    console.log("Before Gateway Balance ==>", erc20ContractBalanceBeforeTransfer);
    

    const tx = await ERC20Gateway.instance.methods.deposit(
      depositParam.amount,
      depositParam.beneficiary,
      depositParam.feeGasPrice,
      depositParam.feeGasLimit,
      depositParam.valueToken,
    ).send(
      { 
        from: depositParam.depositor,
        gas: "1000000",
        gasPrice: "0x01",
       },
    );
      
    console.log("Tranasction Object--->",tx);
    // console.log('TX string  ', JSON.stringify(tx));
  
    const depositorBalanceAfterTransfer = await valueToken.methods.balanceOf(depositParam.depositor).call();
    const erc20ContractBalanceAfterTransfer = await valueToken.methods.balanceOf(ERC20Gateway.address).call();

    console.log("After Depositor Balance ==> ", depositorBalanceAfterTransfer);
    console.log("After Gateway bal===>", erc20ContractBalanceAfterTransfer);
  });

  it('Confirms deposit', async () => { 

  });
});