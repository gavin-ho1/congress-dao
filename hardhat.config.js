require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: "0.8.28",
  gasReporter: {
    enabled: true,
    token: "ETH",
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY, 
    L2Etherscan: process.env.ETHERSCAN_API_KEY,
    L1Etherscan: process.env.ETHERSCAN_API_KEY,
  },
};
