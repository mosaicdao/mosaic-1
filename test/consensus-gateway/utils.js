const web3 = require('../test_lib/web3.js');
const Utils = require('../test_lib/utils.js');

const CONSENSUS_GATEWAY_INBOX_OFFSET = 4;
const CONSENSUS_GATEWAY_OUTBOX_OFFSET = 1;
const DEPOSIT_INTENT_TYPEHASH = web3.utils.soliditySha3('DepositIntent(uint256 amount,address beneficiary)');
const CHANNEL_TYPEHASH = web3.utils.keccak256('MosaicMessageBusChannel(address outbox, address inbox)');
const DOMAIN_SEPARATOR_TYPEHASH = web3.utils.keccak256('MosaicMessageBus(string name,string version,bytes32 metachainId,bytes32 channelSeparator)');
const DOMAIN_SEPARATOR_VERSION = '0';
const MESSAGE_BUS_DOMAIN_SEPARATOR_NAME = 'Mosaic-Bus';

function getDepositIntentHash(amount, beneficiary) {
  return web3.utils.sha3(
    web3.eth.abi.encodeParameters(
      ['bytes32', 'uint256', 'address'],
      [DEPOSIT_INTENT_TYPEHASH, amount.toString(), beneficiary],
    ),
  );
}

function getChannelIdentifier(metachainId, outbox, inbox) {
  const channelSeparator = web3.utils.sha3(Utils.encodeParameters(
    [
      'bytes32',
      'address',
      'address',
    ],
    [
      CHANNEL_TYPEHASH,
      outbox,
      inbox,
    ],
  ));
  return web3.utils.sha3(Utils.encodeParameters(
    [
      'bytes32',
      'string',
      'string',
      'bytes32',
      'bytes32',
    ],
    [
      DOMAIN_SEPARATOR_TYPEHASH,
      MESSAGE_BUS_DOMAIN_SEPARATOR_NAME,
      DOMAIN_SEPARATOR_VERSION,
      metachainId,
      channelSeparator,
    ],
  ));
}

module.exports = {
  DEPOSIT_INTENT_TYPEHASH,
  getDepositIntentHash,
  getChannelIdentifier,
  CONSENSUS_GATEWAY_INBOX_OFFSET,
  CONSENSUS_GATEWAY_OUTBOX_OFFSET,
};
