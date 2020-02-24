module.exports = {
  networks: {
    development: {
      host: 'localhost',
      network_id: '*',
      websocket: true,
      port: 8545,
      gas: 6000000,
      gasPrice: 0x01,
    },
  },
  compilers: {
    solc: {
      version: '0.5.13',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
      evmVersion: 'istanbul',
    },
  },
  mocha: {
    enableTimeouts: false,
  },
};
