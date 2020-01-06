const MerklePatriciaProof = artifacts.require('./MerklePatriciaProof');
const ConsensusCogateway = artifacts.require('./ConsensusCogateway');

module.exports = function (deployer) {
  deployer.deploy(MerklePatriciaProof);
  deployer.link(MerklePatriciaProof, ConsensusCogateway);
  deployer.deploy(ConsensusCogateway);
};
