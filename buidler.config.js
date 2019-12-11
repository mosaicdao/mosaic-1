usePlugin('@nomiclabs/buidler-truffle5');

module.exports = {
  defaultNetwork: 'development',
  networks: {
    development: {
      url: 'http://localhost:8545',
      gas: 12000000,
      gasPrice: 0x01,
    },
  },
  solc: {
    version: '0.5.13',
    optimizer: {
      enabled: true,
      runs: 200,
    },
    evmVersion: 'istanbul'
  },
  mocha: {
    enableTimeouts: false
  }
};
