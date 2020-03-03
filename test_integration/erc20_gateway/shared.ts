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

'use strict';

import Web3 from 'web3';
import BN = require('bn.js');

import { Anchor } from '../../interacts/Anchor';
import { ERC20Gateway } from '../../interacts/ERC20Gateway';
import { Gen0ERC20Cogateway as ERC20Cogateway } from '../../interacts/Gen0ERC20Cogateway';
import { ERC20I } from '../../interacts/ERC20I';

/**
 * It represents type of contract instance and address of it.
 */
export class ContractEntity<Type> {
  address: string;
  instance: Type;

  constructor() {
  }
}

/**
 * It contains instances of the contracts
 */
class Contract {

  public OriginAnchor: ContractEntity<Anchor>;

  public AuxilaryAnchor: ContractEntity<Anchor>;

  public ERC20Gateway: ContractEntity<ERC20Gateway>;

  public ERC20Cogateway: ContractEntity<ERC20Cogateway>;

  public ValueToken: ContractEntity<ERC20I>;

  public UtilityToken: ContractEntity<ERC20I>;

  constructor() {
    this.OriginAnchor = new ContractEntity<Anchor>();
    this.AuxilaryAnchor = new ContractEntity<Anchor>();
    this.ERC20Gateway = new ContractEntity<ERC20Gateway>();
    this.ERC20Cogateway = new ContractEntity<ERC20Cogateway>();
    this.ValueToken = new ContractEntity<ERC20I>();
    this.UtilityToken = new ContractEntity<ERC20I>();
  }
}

/**
 * An object that is shared across modules.
 */
class Shared {
  public artifacts: any;
  public accounts: any;
  public contracts: Contract;
  public web3: Web3;
  public depositor: string;
  public facilitator: string;
  public metachainId: string;
  public utilityTokenMasterCopy: string;
  public coconsensus: string;
  public consensus: string;
  public totalTokenSupply: BN;

  constructor() {
    this.artifacts = {};
    this.contracts =  new Contract();
    this.web3 = new Web3('http://localhost:9545');
    // For testing use 1 block confirmation.
    // @ts-ignore
    this.web3.transactionConfirmationBlocks = 1;
  }
}

export default new Shared();
