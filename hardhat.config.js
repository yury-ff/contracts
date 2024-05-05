require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */

const ALCHEMY_API_KEY = "OMCSmugdX0uXmsu7Rtpmkzv5WjzPhFgf";
const PRIVATE_KEY =
  "6e1c57f154004400b499ab82bf99ed05211d9dff37b8ac7305bf916e1d2c2a53";

module.exports = {
  solidity: "0.8.20",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
      details: {
        yul: false,
      },
    },
  },
  networks: {
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY],
    },
  },
};



//forge create --rpc-url "https://eth-sepolia.g.alchemy.com/v2/8ihtlloOPOfwjIwAQNjuzLlzu2S-ZKbZ" --constructor-args "1000000000000000" "0x668B6724F80591FC5482Aa628017Ee6338898E52" --private-key "c19071cae74771e9950cefd6a76cf2e0fecd1f23b60cc0bef209ddf19754052a" --out contracts/out contracts/tokens/Tuto.sol:Tuto