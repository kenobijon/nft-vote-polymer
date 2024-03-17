const hre = require("hardhat");
const ethers = require("ethers");
const { getConfigPath } = require("./private/_helpers.js");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const config = require(getConfigPath());
  const argsObject = require("../contracts/arguments.js");
  const networkName = hre.network.name;

  const contractType = config["deploy"][`${networkName}`];

  const IbcBallot = await hre.ethers.getContractFactory("IbcBallot");
  const IbcProofOfVoteNFT = await hre.ethers.getContractFactory("IbcProofOfVoteNFT");
  // Deploy the contract
  const proposalNames = [
    "0x506f6c796d6572206272696e67732049424320746f20457468657265756d0000",
    "0x506f6c796d6572206272696e67732049424320746f20616c6c206f6620746800",
  ];
  const ibcBallot = await IbcBallot.deploy(proposalNames, process.env.OP_DISPATCHER_SIM);

  console.log(`Contract ${contractType} deployed to ${ibcBallot.target} on network ${networkName}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
