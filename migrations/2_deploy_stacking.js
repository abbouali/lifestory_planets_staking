const LifestoryPlanetStaking = artifacts.require("LifestoryPlanetStaking")

module.exports = async function (deployer, network, accounts) {
  let planetAddress = "0x04e9F78Ae13cc54Bc50C70155ED23BA17Bf0a527"; //TO EDIT
  await deployer.deploy(LifestoryPlanetStaking, planetAddress);
  lifestoryPlanetStaking = await LifestoryPlanetStaking.deployed();
}