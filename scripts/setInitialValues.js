const { sendTxn, contractAt } = require("./shared/helpers");

async function main() {
  const factoryAddr = "0xE5506689b16877F92A887F4AFC31b8C16be15B98";
  const auctionAddr = "0x4B518c8527023F15947A0189Ec02c798E9B13428";

  const factory = await contractAt("NitrilityFactory", factoryAddr);
  const auction = await contractAt("NitrilityAuction", auctionAddr);

  await sendTxn(factory.setAuctionAddr(auctionAddr), "Factory.setAuctionAddr");
  await sendTxn(auction.setFactory(factoryAddr), "Auction.setFactory");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
