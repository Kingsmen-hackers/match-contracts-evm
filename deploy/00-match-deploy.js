const { developmentChains } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const args = []

  if (developmentChains.includes(network.name)) {
    await deploy("Marketplace", {
      from: deployer,
      log: true,
      args: args,
    })
    log("Match Deployed!")
    log("---------------------------------")
  }
}

module.exports.tags = ["all"]
