const { ethers } = require("hardhat")

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying Smart Contract For Auction with the account:", deployer.address);

  const token = await ethers.deployContract("NitrilityAuction");

  console.log("Token address:", await token.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });