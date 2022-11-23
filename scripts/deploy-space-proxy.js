const { ethers, upgrades } = require("hardhat");

async function main() {
  const Space = await ethers.getContractFactory("Space");
  const space = await upgrades.deployProxy(Space, ["<uri>", "Name", "0xDb6770F50728e3FB61fAc481Da6641C802F8B9A7"]);
  await space.deployed();
  console.log("Space deployed to:", space.address);
}

main();