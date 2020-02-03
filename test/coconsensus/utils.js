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

'use strict';

const BN = require('bn.js');

const Utils = require('../test_lib/utils.js');

const Coconsensus = artifacts.require('CoconsensusTest');
const OriginProtocore = artifacts.require('TestOriginProtocore');
const OriginObserver = artifacts.require('OriginObserverTest');
const SelfProtocore = artifacts.require('TestSelfProtocore');

// Deploy self protocore contract
async function deploySelfProtocore(coconsensusAddress) {
  const config = {};

  config.setupParams = {};
  config.setupParams.coconsensus = coconsensusAddress;

  config.genesis = {};
  config.genesis.auxiliaryParentVoteMessageHash = Utils.getRandomHash();
  config.genesis.auxiliarySourceTransitionHash = Utils.getRandomHash();
  config.genesis.auxiliarySourceBlockHash = Utils.getRandomHash();
  config.genesis.auxiliaryTargetBlockHash = Utils.getRandomHash();
  config.genesis.auxiliaryAccumulatedGas = new BN(1000000);
  config.genesis.auxiliaryMetachainId = Utils.getRandomHash();
  config.genesis.domainSeparator = Utils.getRandomHash();
  config.genesis.epochLength = new BN(100);
  config.genesis.dynasty = new BN(0);
  config.genesis.metablockHeight = new BN(Utils.getRandomNumber(1000));

  config.genesis.auxiliarySourceBlockNumber = new BN(
    Utils.getRandomNumber(10000) * config.genesis.epochLength,
  );
  config.genesis.auxiliaryTargetBlockNumber = config.genesis.auxiliarySourceBlockNumber
    .add(config.genesis.epochLength);

  config.contracts = {};

  // Deploy the self protocore contract.
  config.contracts.selfProtocore = await SelfProtocore.new();

  // Set the value of genesis variables
  await config.contracts.selfProtocore.setGenesisStorage(
    config.genesis.auxiliaryMetachainId,
    config.genesis.domainSeparator,
    config.genesis.epochLength,
    config.genesis.dynasty,
    config.genesis.metablockHeight,
    config.genesis.auxiliaryParentVoteMessageHash,
    config.genesis.auxiliarySourceTransitionHash,
    config.genesis.auxiliarySourceBlockHash,
    config.genesis.auxiliarySourceBlockNumber,
    config.genesis.auxiliaryTargetBlockHash,
    config.genesis.auxiliaryTargetBlockNumber,
    config.genesis.auxiliaryAccumulatedGas,
  );

  await config.contracts.selfProtocore.setCoconsensus(
    config.setupParams.coconsensus,
  );

  return config;
}

// Deploy origin protocore contract.
async function deployOriginProtocore(
  accountProvider,
  selfProtocoreAddress,
  coconsensusAddress,
) {
  const config = {};
  config.genesis = {};
  config.genesis.originParentVoteMessageHash = Utils.getRandomHash();
  config.genesis.originSourceBlockHash = Utils.ZERO_BYTES32;
  config.genesis.originSourceBlockNumber = new BN(0);
  config.genesis.originTargetBlockHash = Utils.getRandomHash();
  config.genesis.originMetachainId = Utils.getRandomHash();
  config.genesis.domainSeparator = Utils.getRandomHash();
  config.genesis.epochLength = new BN(100);
  config.genesis.dynasty = new BN(0);
  config.genesis.metablockHeight = new BN(Utils.getRandomNumber(1000));
  config.genesis.selfProtocore = selfProtocoreAddress;

  config.setupParams = {};
  config.setupParams.coconsensus = coconsensusAddress;

  config.genesis.originTargetBlockNumber = new BN(
    Utils.getRandomNumber(10000) * config.genesis.epochLength,
  );

  config.contracts = {};

  // Deploy the origin protocore contract.
  config.contracts.originProtocore = await OriginProtocore.new();

  // Set the value of genesis variables
  await config.contracts.originProtocore.setGenesisStorage(
    config.genesis.originMetachainId,
    config.genesis.domainSeparator,
    config.genesis.epochLength,
    config.genesis.dynasty,
    config.genesis.metablockHeight,
    config.genesis.selfProtocore,
    config.genesis.originParentVoteMessageHash,
    config.genesis.originSourceBlockHash,
    config.genesis.originSourceBlockNumber,
    config.genesis.originTargetBlockHash,
    config.genesis.originTargetBlockNumber,
  );

  await config.contracts.originProtocore.setCoconsensus(
    config.setupParams.coconsensus,
  );

  return config;
}

// Deploy origin observer contract
async function deployOriginObserver(coconsensusAddress) {
  const config = {};
  config.genesis = {};
  config.genesis.originBlockNumber = new BN(5);
  config.genesis.originStateRoot = Utils.getRandomHash();
  config.genesis.maxStateRootLimitCount = new BN(100);

  config.contracts = {};

  // Deploy the origin observer contract.
  config.contracts.originObserver = await OriginObserver.new();

  await config.contracts.originObserver.setGenesisStorageVariables(
    config.genesis.originBlockNumber,
    config.genesis.originStateRoot,
    config.genesis.maxStateRootLimitCount,
  );

  await config.contracts.originObserver.setCoconsensus(coconsensusAddress);

  return config;
}

// Deploy coconsensus contract
async function deployCoconsensus(accountProvider) {
  const config = {};

  // Contract addresses.
  config.contracts = {};
  config.contracts.coconsensus = await Coconsensus.new();

  const selfProtocoreData = await deploySelfProtocore(
    config.contracts.coconsensus.address,
  );

  const originProtocoreData = await deployOriginProtocore(
    accountProvider,
    selfProtocoreData.contracts.selfProtocore.address,
    config.contracts.coconsensus.address,
  );

  const originObserverData = await deployOriginObserver(
    config.contracts.coconsensus.address,
  );

  config.contracts.selfProtocore = selfProtocoreData.contracts.selfProtocore;
  config.contracts.originObserver = originObserverData.contracts.originObserver;
  config.contracts.originProtocore = originProtocoreData.contracts.originProtocore;

  // Genesis data for coconsensus contract.
  config.genesis = {};
  config.genesis.metachainIds = [
    originProtocoreData.genesis.originMetachainId,
    selfProtocoreData.genesis.auxiliaryMetachainId,
  ];

  config.genesis.protocores = [
    originProtocoreData.contracts.originProtocore.address,
    selfProtocoreData.contracts.selfProtocore.address,
  ];

  config.genesis.protocoreData = {};
  config.genesis.protocoreData[
    selfProtocoreData.genesis.auxiliaryMetachainId
  ] = selfProtocoreData;

  config.genesis.protocoreData[
    originProtocoreData.genesis.originMetachainId
  ] = originProtocoreData;

  config.genesis.observers = [
    originObserverData.contracts.originObserver.address,
    Utils.ZERO_BYTES20,
  ];

  config.genesis.observerData = {};
  config.genesis.observerData[
    originProtocoreData.genesis.originMetachainId
  ] = originObserverData;

  // eslint-disable-next-line prefer-destructuring
  config.genesis.originMetachainId = config.genesis.metachainIds[0];

  // eslint-disable-next-line prefer-destructuring
  config.genesis.auxiliaryMetachainId = config.genesis.metachainIds[1];

  await config.contracts.coconsensus.setGenesisStorage(
    config.genesis.metachainIds,
    config.genesis.protocores,
    config.genesis.observers,
  );

  await config.contracts.coconsensus.setup();

  return config;
}

module.exports = {
  deployCoconsensus,
};
