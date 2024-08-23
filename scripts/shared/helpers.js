const { ethers } = require("hardhat")
const { 
  MUMBAI_URL,
  MUMBAI_API_KEY
} = require('../../env.json')

// const providers = {
//   mumbai: new ethers.providers.JsonRpcProvider(MUMBAI_URL),
// }

// const signers = {
//   mumbai: new ethers.Wallet(MUMBAI_API_KEY).connect(providers.mumbai),
// }

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function sendTxn(txnPromise, label) {
  console.info(`Processsing ${label}:`)
  const txn = await txnPromise
  console.info(`Sending ${label}...`)
  await txn.wait(2)
  console.info(`... Sent! ${txn.hash}`)
  return txn
}

async function contractAt(name, address, provider, options) {
  let contractFactory = await ethers.getContractFactory(name, options)
  if (provider) {
    contractFactory = contractFactory.connect(provider)
  }
  return await contractFactory.attach(address)
}

module.exports = {
  // providers,
  // signers,
  sendTxn,
  contractAt,
  sleep
}