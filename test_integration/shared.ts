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
//
// ----------------------------------------------------------------------------
//
// http://www.simpletoken.org/
//
// ----------------------------------------------------------------------------
import {Axiom} from "../interacts/Axiom";
import {Committee} from "../interacts/Committee";
import {Consensus} from "../interacts/Consensus";
import {Core} from "../interacts/Core";
import {Reputation} from "../interacts/Reputation";
import {ERC20I} from "../interacts/ERC20I";
import {Anchor} from "../interacts/Anchor";

const Web3 = require("web3");

const web3 = new Web3('http://localhost:8545');
// For testing use 1 block confirmation.
web3.transactionConfirmationBlocks = 1;

class ContractEntity<Type> {
  address: string;
  instance: Type;

  constructor() {
  }
}

class Contract {
  public Axiom: ContractEntity<Axiom>;

  public Committee: ContractEntity<Committee>;

  public Consensus: ContractEntity<Consensus>;

  public Core: ContractEntity<Core>;

  public Reputation: ContractEntity<Reputation>;

  public Anchor: ContractEntity<Anchor>;

  public MOST: ContractEntity<ERC20I>;

  public WETH: ContractEntity<ERC20I>;

  constructor() {
    this.Axiom = new ContractEntity<Axiom>();
    this.Committee = new ContractEntity<Committee>();
    this.Consensus = new ContractEntity<Consensus>();
    this.Core = new ContractEntity<Core>();
    this.Reputation = new ContractEntity<Reputation>();
    this.Anchor = new ContractEntity<Anchor>();
    this.MOST = new ContractEntity<ERC20I>();
    this.WETH = new ContractEntity<ERC20I>();
  }

}

class Origin {
  public funder: string;
  public web3: any;
  public keys: {
    techGov: string;
    validators: string[];
  };

  public contracts: Contract;

  constructor() {
    this.keys = {
      techGov: '',
      validators: [],
    };

    this.contracts = new Contract();
    this.web3 = web3;
  }

}
/**
 * An object that is shared across modules.
 */
class Shared {
  public artifacts: any;
  public origin: Origin;

  constructor() {
    this.artifacts = {};
    this.origin =  new Origin();
  }
}

export default new Shared();
