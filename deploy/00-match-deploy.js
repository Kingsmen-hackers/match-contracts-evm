const { developmentChains } = require("../helper-hardhat-config");
const verify = require("../utils/verify")
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const args = [];

  const matchContract = await deploy("Marketplace", {
    from: deployer,
    log: true,
    args: args,
  });
  log("Match Deployed!");
  log("---------------------------------");
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    await verify(matchContract.address, args);
    log("---------------------");
  }
};

module.exports.tags = ["all"];
