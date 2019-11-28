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

import shared from '../shared';
import Interacts from "../../interacts/Interacts";
import Utils from "../Utils";

describe('Axiom::newMetaChain', async () => {

  it('New metachain creation', async () => {

    const axiom = shared.origin.contracts.Axiom;
    const stateRoots = 100;
    const rlpBlockHeader = '0xf901f9a083cafc574e1f51ba9dc0568fc617a08ea2429fb384059c972f13b19fa1c8dd55a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347948888f1f195afa192cfee860698584c030f4c9db1a0ef1552a40b7165c3cd773806b9e0c165b75356e0314bf0706f279c729f51e017a05fe50b260da6308036625b850b5d6ced6d0a9f814c0688bc91ffb7b7a3a54b67a0bc37d79753ad738a6dac4921e57392f145d8887476de3f783dfa7edae9283e52b90100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008302000001832fefd8825208845506eb0780a0bd4472abb6659ebe3ee06ee4d7b72a00a9f4d001caca51342001075469aff49888a13a5a8c8f2bb1c4';
    const rawTx = axiom.instance.methods.newMetaChain(
      stateRoots,
      rlpBlockHeader as any,
    );
    console.log('consensus address  in axiom :- ',await axiom.instance.methods.consensus().call());
    await Utils.sendTransaction(rawTx, {
      from: shared.origin.keys.techGov,
      gas: '9000000',
    }).then(value => {
      console.log('value :- ',value);
    }).catch(error => {
      console.log('error in metachain :- ',error);
    });
    // const consensusContractInstance = Interacts.getConsensus(await axiom.instance.methods.consensus().call());

  });

});
