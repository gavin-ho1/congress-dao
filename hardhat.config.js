require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true, 
        runs: 1000,
      },
      viaIR: true       
    }
  },
  gasReporter: {
    enabled: process.env.ENABLED === 'true',
    token: "ETH",
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY, 
    L2Etherscan: process.env.ETHERSCAN_API_KEY,
    L1Etherscan: process.env.ETHERSCAN_API_KEY,
    outputJSON: true,
  },
};

