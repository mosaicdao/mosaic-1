/* eslint-disable no-await-in-loop */
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

const TestProtocore = artifacts.require('TestProtocore');
const SpyCoconsensus = artifacts.require('SpyCoConsensus');

const ProtocoreUtils = require('./utils.js');
const Utils = require('../test_lib/utils.js');

const config = {};

async function addToFVS(
  protocore,
  validators,
  metablockHeight,
) {
  for (let i = 0; i < validators.length; i += 1) {
    await protocore.addToFVS(validators[i].address, metablockHeight);
  }
}

async function openKernel(
  protocore,
  coconsensus,
) {
  await coconsensus.openKernel(
    protocore.address,
    Utils.getRandomHash(),
  );
}

function isObject(obj) {
  return typeof obj === 'object' && obj !== null;
}

const OPEN_KERNEL_TYPE = 'open-kernel';
const PROPOSE_LINK_TYPE = 'propose-link';
const VOTE_TYPE = 'vote';
const CHECK_TYPE = 'check';

function isSupportedBehaviourType(type) {
  return type === OPEN_KERNEL_TYPE
  || type === PROPOSE_LINK_TYPE
  || type === VOTE_TYPE
  || type === CHECK_TYPE;
}

const debugMode = false;

/**
 * @param {Object} cfg - Test configuration object that defines the test initial state,
 *                       steps to be made and checks to be done on an each step.
 * @param {Object} cfg.state - Initial state of the test.
 * @param {Object[]} cfg.state.vs - Defines an array of validators by
 *                                  { fsvBeginDelta, fvsEndDelta } object.
 *                                  Later in the test a validator is identified
 *                                  by the index in this array.
 * @param {number} cfg.state.vs[].fvsBeginDelta
 * @param {number} cfg.state.vs[].fvsEndDelta
 * @param {Object[]} cfg.behaviour - Defines steps to be taken in the test.
 * @param {Object} cfg.behaviour[] - Step to be done.
 * @param {string} cfg.behaviour[].type - Defines a type:
 *                                          - "open-kernel"
 *                                          - "propose-link"
 *                                          - "vote"
 *                                          - "check"
 * @param {string} cfg.behaviour[].linkId - In case of a "propose-link" defines
 *                                          a link identifier for a newly proposed link
 *                                          to be referred from other parts of the test.
 *                                          In case of a "vote" defines a link to register
 *                                          a vote for.
 *                                          In case of a "check" defines a link to check for.
 * @param {boolean} cfg.behaviour[].isFinalisation - In case of a "propose-link" step
 *                                                   defines is it a finalisation link
 *                                                   that needs to be created or not.
 * @param {string} cfg.behaviour[].parentVoteMessageHash - In case of a "propose-link" defines
 *                                                         a parent vote message hash of
 *                                                         a newly proposed link.
 * @param {string} cfg.behaviour[].parentVoteMessageLinkId - In case of a "propose-link" defines
 *                                                           an linkId of a parent vote message.
 * @param {number} cfg.behaviour[].validatorIndex - In case of a "vote" step, defines a
 *                                                  validator index.
 * @param {boolean} cfg.behaviour[].checkSourceIsFinalised - In case of a "check" asserts that
 *                                                           a source checkpoint of a link
 *                                                           is finalised.
 * @param {boolean} cfg.behaviour[].checkTargetIsJustified - In case of a "check" asserts that
 *                                                           a target checkpoint of a link
 *                                                           is justified.
 */
async function run(
  cfg,
  protocore,
  coconsensus,
) {
  if (debugMode) {
    console.log('------- Start -------');
  }

  assert(isObject(cfg));
  assert(isObject(cfg.state));
  assert(Array.isArray(cfg.state.vs));

  const validators = [];
  {
    const openKernelHeight = await protocore.openKernelHeight();

    for (let i = 0; i < cfg.state.vs.length; i += 1) {
      const vc = cfg.state.vs[i];
      assert(isObject(vc));
      assert(typeof vc.fvsBeginDelta === 'number');
      assert(typeof vc.fvsEndDelta === 'number');
      assert(vc.fvsBeginDelta <= vc.fvsEndDelta);

      const v = await ProtocoreUtils.Validator.create();
      validators.push(v);

      for (let d = vc.fvsBeginDelta; d <= vc.fvsEndDelta; d += 1) {
        const height = openKernelHeight.addn(d);
        await protocore.addToFVS(v.address, height);
      }
    }
  }

  assert(Array.isArray(cfg.behaviour));

  const voteMessageHashes = {};

  for (let i = 0; i < cfg.behaviour.length; i += 1) {
    const behaviour = cfg.behaviour[i];
    assert(isObject(behaviour));

    const { type } = behaviour;
    assert(isSupportedBehaviourType(type));

    if (type === OPEN_KERNEL_TYPE) {
      if (debugMode) {
        console.log(`step = ${i}, type: ${OPEN_KERNEL_TYPE}`);
      }

      await openKernel(protocore, coconsensus);

      if (debugMode) {
        const openKernelHeight = await protocore.openKernelHeight();
        console.log(`openKernelHeight = ${openKernelHeight}`);
        const fvsQuorum = await config.protocore.fvsQuorums(openKernelHeight);
        let fvsQuorumPrevious;
        if (!openKernelHeight.isZero()) {
          fvsQuorumPrevious = await config.protocore.fvsQuorums(openKernelHeight.subn(1));
        }
        console.log(`fvsQuorumPrevious = ${fvsQuorumPrevious}, fvsQuorum = ${fvsQuorum}`);
      }
    } else if (type === PROPOSE_LINK_TYPE) {
      if (debugMode) {
        console.log(`step = ${i}, type: ${PROPOSE_LINK_TYPE}`);
      }

      const { linkId } = behaviour;
      assert(typeof linkId === 'string');
      assert(linkId !== '');
      assert(!Object.prototype.hasOwnProperty.call(voteMessageHashes, linkId));

      const { parentVoteMessageHash } = behaviour;
      const { parentVoteMessageLinkId } = behaviour;

      assert(parentVoteMessageHash === undefined || parentVoteMessageLinkId === undefined);

      let pvmh = '';
      if (parentVoteMessageHash !== undefined) {
        assert(typeof parentVoteMessageHash === 'string');
        assert(parentVoteMessageHash !== '');
        pvmh = parentVoteMessageHash;
      } else {
        assert(typeof parentVoteMessageLinkId === 'string');
        assert(parentVoteMessageLinkId !== '');
        assert(Object.prototype.hasOwnProperty.call(voteMessageHashes, parentVoteMessageLinkId));
        pvmh = voteMessageHashes[parentVoteMessageLinkId];
      }
      assert(typeof pvmh === 'string');
      assert(pvmh !== '');


      const { isFinalisation } = behaviour;
      assert(typeof isFinalisation === 'boolean');

      if (isFinalisation === true) {
        const {
          voteMessageHash,
        } = await ProtocoreUtils.proposeFinalisationLinkInternal(
          protocore,
          pvmh,
        );

        const f = await protocore.isFinalisationLink(voteMessageHash);
        assert(f);

        voteMessageHashes[linkId] = voteMessageHash;
      } else {
        const {
          voteMessageHash,
        } = await ProtocoreUtils.proposeNonFinalisationLinkInternal(
          protocore,
          pvmh,
        );

        const f = await protocore.isFinalisationLink(voteMessageHash);
        assert(!f);

        voteMessageHashes[linkId] = voteMessageHash;
      }
      assert(Object.prototype.hasOwnProperty.call(voteMessageHashes, linkId));
      assert(typeof voteMessageHashes[linkId] === 'string');
      assert(voteMessageHashes[linkId] !== '');
    } else if (type === VOTE_TYPE) {
      if (debugMode) {
        console.log(`step = ${i}, type: ${VOTE_TYPE}`);
      }

      const { validatorIndex } = behaviour;
      assert(typeof validatorIndex === 'number');
      assert(validatorIndex >= 0 && validatorIndex < validators.length);

      const v = validators[validatorIndex];

      const { linkId } = behaviour;
      assert(typeof linkId === 'string');
      assert(linkId !== '');
      assert(Object.prototype.hasOwnProperty.call(voteMessageHashes, linkId));

      const vmh = voteMessageHashes[linkId];

      const sig = await v.ecsign(vmh);

      await protocore.registerVote(vmh, sig.r, sig.s, sig.v);

      if (debugMode) {
        const openKernelHeight = await protocore.openKernelHeight();

        const voteCount = await protocore.getVoteCount(vmh, openKernelHeight);
        let previousVoteCount;
        if (!openKernelHeight.isZero()) {
          previousVoteCount = await protocore.getVoteCount(vmh, openKernelHeight.subn(1));
        }
        console.log(`previousVoteCount = ${previousVoteCount}, voteCount = ${voteCount}`);
      }
    } else if (type === CHECK_TYPE) {
      if (debugMode) {
        console.log(`step = ${i}, type: ${CHECK_TYPE}`);
      }

      const { linkId } = behaviour;
      assert(typeof linkId === 'string');
      assert(linkId !== '');
      assert(Object.prototype.hasOwnProperty.call(voteMessageHashes, linkId));

      const vmh = voteMessageHashes[linkId];

      const { checkSourceIsFinalised } = behaviour;
      if (checkSourceIsFinalised !== undefined) {
        assert(typeof checkSourceIsFinalised === 'boolean');

        const sourceFinalisationStatus = await config.protocore.getSourceFinalisation(vmh);
        if (checkSourceIsFinalised === true) {
          assert.isOk(
            ProtocoreUtils.isFinalised(sourceFinalisationStatus),
          );
        } else {
          assert.isNotOk(
            ProtocoreUtils.isFinalised(sourceFinalisationStatus),
          );
        }
      }

      const { checkTargetIsJustified } = behaviour;
      if (checkTargetIsJustified !== undefined) {
        assert(typeof checkTargetIsJustified === 'boolean');

        const targetFinalisationStatus = await config.protocore.getTargetFinalisation(vmh);
        if (checkTargetIsJustified === true) {
          assert.isOk(
            ProtocoreUtils.isJustified(targetFinalisationStatus),
          );
        } else {
          assert.isNotOk(
            ProtocoreUtils.isJustified(targetFinalisationStatus),
          );
        }
      }

      assert(checkSourceIsFinalised !== undefined || checkTargetIsJustified !== undefined);
    } else {
      throw new Error('Invalid type has encountered.');
    }
  }

  if (debugMode) {
    console.log('-------- End --------');
  }

  return {
    validators,
    voteMessageHashes,
  };
}

async function proposeAndJustifyLink(
  protocore,
  coconsensus,
  parentVoteMessageHash,
) {
  const linkId = Utils.getRandomHash();
  const cfg = {
    state: {
      vs: [
        { fvsBeginDelta: 1, fvsEndDelta: 2 },
        { fvsBeginDelta: 1, fvsEndDelta: 2 },
        { fvsBeginDelta: 1, fvsEndDelta: 2 },
      ],
    },
    behaviour: [
      {
        type: OPEN_KERNEL_TYPE,
      },
      {
        type: OPEN_KERNEL_TYPE,
      },
      {
        type: PROPOSE_LINK_TYPE,
        linkId,
        isFinalisation: false,
        parentVoteMessageHash,
      },
      {
        type: CHECK_TYPE,
        linkId,
        checkTargetIsJustified: false,
      },
      {
        type: VOTE_TYPE,
        linkId,
        validatorIndex: 0,
      },
      {
        type: CHECK_TYPE,
        linkId,
        checkTargetIsJustified: false,
      },
      {
        type: VOTE_TYPE,
        linkId,
        validatorIndex: 2,
      },
      {
        type: CHECK_TYPE,
        linkId,
        checkTargetIsJustified: true,
      },
    ],
  };

  const {
    voteMessageHashes,
  } = await run(cfg, protocore, coconsensus);

  assert(Object.hasOwnProperty.call(voteMessageHashes, linkId));
  assert(voteMessageHashes[linkId] !== '');

  return voteMessageHashes[linkId];
}


contract('Protocore::registerVoteInternal', () => {
  beforeEach(async () => {
    config.coconsensus = await SpyCoconsensus.new();
    config.domainSeparator = Utils.getRandomHash();
    config.epochLength = new BN(100);
    config.metachainId = Utils.getRandomHash();

    config.genesisKernelHeight = new BN(1);
    config.genesisKernelHash = Utils.getRandomHash();
    config.genesisParentVoteMessageHash = Utils.getRandomHash();
    config.genesisSourceTransitionHash = Utils.getRandomHash();
    config.genesisSourceBlockHash = Utils.getRandomHash();
    config.genesisTargetBlockHash = Utils.getRandomHash();
    config.genesisSourceBlockNumber = new BN(0);
    config.genesisTargetBlockNumber = new BN(config.epochLength);
    config.genesisVoteMessageHash = ProtocoreUtils.hashVoteMessage(
      config.domainSeparator,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
    );
    config.genesisProposedMetablockHeight = new BN(1);

    config.protocore = await TestProtocore.new(
      config.coconsensus.address,
      config.metachainId,
      config.domainSeparator,
      config.epochLength,
      config.genesisKernelHeight,
      config.genesisKernelHash,
      config.genesisParentVoteMessageHash,
      config.genesisSourceTransitionHash,
      config.genesisSourceBlockHash,
      config.genesisTargetBlockHash,
      config.genesisSourceBlockNumber,
      config.genesisTargetBlockNumber,
      config.genesisProposedMetablockHeight,
    );
  });

  contract('Negative Tests', async () => {
    it('should fail if a finalisation status of a target checkpoint '
      + 'is less than registered', async () => {
      const v = await ProtocoreUtils.Validator.create();
      const sig = await v.ecsign(Utils.getRandomHash());

      await Utils.expectRevert(
        config.protocore.registerVote(
          Utils.getRandomHash(),
          sig.r, sig.s, sig.v,
        ),
        'The given link status is at least reported.',
      );
    });
    it('should fail if a link height inclusion principle is not kept', async () => {
      const v = await ProtocoreUtils.Validator.create();

      const {
        voteMessageHash,
      } = await ProtocoreUtils.proposeNonFinalisationLinkInternal(
        config.protocore,
        config.genesisVoteMessageHash,
      );

      await openKernel(config.protocore, config.coconsensus);
      await openKernel(config.protocore, config.coconsensus);

      const sig = await v.ecsign(voteMessageHash);

      await Utils.expectRevert(
        config.protocore.registerVote(
          voteMessageHash,
          sig.r, sig.s, sig.v,
        ),
        'Link height inclusion principle has surpassed.',
      );
    });
    it('should fail if a validator has already voted for a height', async () => {
      const openMetablockHeight = await config.protocore.openKernelHeight();
      const nextMetablockHeight = openMetablockHeight.addn(1);

      const v = await ProtocoreUtils.Validator.create();
      await addToFVS(config.protocore, [v], nextMetablockHeight);

      await openKernel(config.protocore, config.coconsensus);

      const {
        voteMessageHash,
      } = await ProtocoreUtils.proposeNonFinalisationLinkInternal(
        config.protocore,
        config.genesisVoteMessageHash,
      );

      const sig = await v.ecsign(voteMessageHash);

      await config.protocore.registerVote(
        voteMessageHash,
        sig.r, sig.s, sig.v,
      );

      await Utils.expectRevert(
        config.protocore.registerVote(
          voteMessageHash,
          sig.r, sig.s, sig.v,
        ),
        'Validator vote cannot be registered twice in FVS votes at the same height.',
      );
    });
  });

  contract('Positive Tests', async () => {
    it('checks that if a quorum reached a link is justified', async () => {
      const justifiedParentVoteMessageHash = await proposeAndJustifyLink(
        config.protocore,
        config.coconsensus,
        config.genesisVoteMessageHash,
      );

      const linkId = Utils.getRandomHash();

      const cfg = {
        state: {
          vs: [
            { fvsBeginDelta: 1, fvsEndDelta: 1 },
            { fvsBeginDelta: 1, fvsEndDelta: 2 },
            { fvsBeginDelta: 1, fvsEndDelta: 2 },
            { fvsBeginDelta: 2, fvsEndDelta: 2 },
          ],
        },
        behaviour: [
          {
            type: OPEN_KERNEL_TYPE,
          },
          {
            type: OPEN_KERNEL_TYPE,
          },
          {
            type: PROPOSE_LINK_TYPE,
            linkId,
            parentVoteMessageHash: justifiedParentVoteMessageHash,
            isFinalisation: false,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 0,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 3,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 2,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: true,
            checkSourceIsFinalised: false,
          },
        ],
      };

      await run(cfg, config.protocore, config.coconsensus);
    });
    // Instead of coconsensus address, mocked coconsensus should be passed.
    it('checks that if a quorum reached for a finalisation link '
    + 'its source is finalised', async () => {
      const justifiedParentVoteMessageHash = await proposeAndJustifyLink(
        config.protocore,
        config.coconsensus,
        config.genesisVoteMessageHash,
      );

      const linkId = Utils.getRandomHash();

      const cfg = {
        state: {
          vs: [
            { fvsBeginDelta: 1, fvsEndDelta: 1 },
            { fvsBeginDelta: 1, fvsEndDelta: 2 },
            { fvsBeginDelta: 1, fvsEndDelta: 2 },
            { fvsBeginDelta: 2, fvsEndDelta: 2 },
          ],
        },
        behaviour: [
          {
            type: OPEN_KERNEL_TYPE,
          },
          {
            type: OPEN_KERNEL_TYPE,
          },
          {
            type: PROPOSE_LINK_TYPE,
            linkId,
            parentVoteMessageHash: justifiedParentVoteMessageHash,
            isFinalisation: true,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 0,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 3,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 2,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: true,
            checkSourceIsFinalised: true,
          },
        ],
      };

      await run(cfg, config.protocore, config.coconsensus);
    });
    it('checks that a vote of a validator is not double-counting', async () => {
      const justifiedParentVoteMessageHash = await proposeAndJustifyLink(
        config.protocore,
        config.coconsensus,
        config.genesisVoteMessageHash,
      );

      const linkId = Utils.getRandomHash();

      const cfg = {
        state: {
          vs: [
            { fvsBeginDelta: 1, fvsEndDelta: 1 },
            { fvsBeginDelta: 1, fvsEndDelta: 1 },
            { fvsBeginDelta: 1, fvsEndDelta: 1 },
            { fvsBeginDelta: 1, fvsEndDelta: 2 },
            { fvsBeginDelta: 1, fvsEndDelta: 2 },
            { fvsBeginDelta: 2, fvsEndDelta: 2 },
          ],
        },
        behaviour: [
          {
            type: OPEN_KERNEL_TYPE,
          },
          {
            type: PROPOSE_LINK_TYPE,
            linkId,
            parentVoteMessageHash: justifiedParentVoteMessageHash,
            isFinalisation: true,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 0,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 3,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: OPEN_KERNEL_TYPE,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 5,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 3,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: false,
            checkSourceIsFinalised: false,
          },
          {
            type: VOTE_TYPE,
            linkId,
            validatorIndex: 1,
          },
          {
            type: CHECK_TYPE,
            linkId,
            checkTargetIsJustified: true,
            checkSourceIsFinalised: true,
          },
        ],
      };

      await run(cfg, config.protocore, config.coconsensus);
    });
  });
});
