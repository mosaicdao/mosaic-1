const BN = require('bn.js');

const CoreStatus = {
  undefined: 0,
  halted: 1,
  corrupted: 2,
  creation: 3,
  opened: 4,
  precommitted: 5,
};
Object.freeze(CoreStatus);

function isCoreCreated(status) {
  return new BN(CoreStatus.creation).cmp(status) === 0;
}

function isCoreOpened(status) {
  return new BN(CoreStatus.opened).cmp(status) === 0;
}

function isCorePrecommitted(status) {
  return new BN(CoreStatus.precommitted).cmp(status) === 0;
}

function isCoreHalted(status) {
  return new BN(CoreStatus.halted).cmp(status) === 0;
}

function isCoreCorrupted(status) {
  return new BN(CoreStatus.corrupted).cmp(status) === 0;
}

module.exports = {
  isCoreCreated,
  isCoreOpened,
  isCorePrecommitted,
  isCoreHalted,
  isCoreCorrupted,
  CoreStatus,
};
