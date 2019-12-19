const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');

const DOMAIN_SEPARATOR_TYPEHASH = web3.utils.keccak256('EIP712Domain(string name,string version,bytes32 metachainId,address verifyingContract)');
const DOMAIN_SEPARATOR_VERSION = '0';
const MESSAGE_BUS_DOMAIN_SEPARATOR_NAME = 'Message-Bus';
const CONSENSUS_GATEWAY_INBOX_OFFSET = 4;
const CONSENSUS_GATEWAY_OUTBOX_OFFSET = 1;

function getMessageInboxIdentifier(metachainId, verifyingAddress) {
  return web3.utils.sha3(Utils.encodeParameters(
    [
      'bytes32',
      'string',
      'string',
      'bytes32',
      'address',
    ],
    [
      DOMAIN_SEPARATOR_TYPEHASH,
      MESSAGE_BUS_DOMAIN_SEPARATOR_NAME,
      DOMAIN_SEPARATOR_VERSION,
      metachainId,
      verifyingAddress,
    ],
  ));
}

function getMessageOutboxIdentifier(metachainId, verifyingAddress) {
  return web3.utils.sha3(Utils.encodeParameters(
    [
      'bytes32',
      'string',
      'string',
      'bytes32',
      'address',
    ],
    [
      DOMAIN_SEPARATOR_TYPEHASH,
      MESSAGE_BUS_DOMAIN_SEPARATOR_NAME,
      DOMAIN_SEPARATOR_VERSION,
      metachainId,
      verifyingAddress,
    ],
  ));
}

module.exports = {
  getMessageInboxIdentifier,
  getMessageOutboxIdentifier,
  CONSENSUS_GATEWAY_INBOX_OFFSET,
  CONSENSUS_GATEWAY_OUTBOX_OFFSET,
};
