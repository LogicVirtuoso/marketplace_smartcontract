/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-verify");

const {
  ARBITRUM_RPC_PROVIDER,
  PRIVATE_KEY,
  ARBITRUM_API,
} = require("./env.json");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.23",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    arbitrumOne: {
      url: ARBITRUM_RPC_PROVIDER,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: ARBITRUM_API,
  },
  sourcify: {
    enabled: true,
    // Optional: specify a different Sourcify server
    apiUrl: "https://sourcify.dev/server",
    // Optional: specify a different Sourcify repository
    browserUrl: "https://repo.sourcify.dev",
  },
};
