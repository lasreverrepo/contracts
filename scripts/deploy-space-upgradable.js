const { ethers, upgrades } = require("hardhat");

async function main() {
  const Space = await ethers.getContractFactory("Space");
  const Governor = await ethers.getContractFactory("SoulboundGovernor");
  const TimelockControllerUpgradeable = await ethers.getContractFactory("TimelockControllerUpgradeable");

  const space = await upgrades.deployProxy(Space, ["<Pics storage uri>", "<Name>", "0xDb6770F50728e3FB61fAc481Da6641C802F8B9A7"]);
  await space.deployed();
  console.log("Space deployed to:", space.address);

  const timelock = await upgrades.deployProxy(TimelockControllerUpgradeable, []);
  await timelock.deployed();
  console.log("Timelock deployed at ", timelock.address)

  const governor = await upgrades.deployProxy(Governor, [space.address, timelock.address]);
  await governor.deployed();
  console.log("Governor deployed at ", governor.address)
}

main();