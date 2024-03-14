const hre = require("hardhat");
const ethers = require("ethers");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const IbcBallot = await hre.ethers.getContractFactory("IbcBallot");
    const IbcProofOfVoteNFT = await hre.ethers.getContractFactory("IbcProofOfVoteNFT");
    // Deploy the contract
    const proposalNames = [
        "0x506f6c796d6572206272696e67732049424320746f20457468657265756d0000",
        "0x506f6c796d6572206272696e67732049424320746f20616c6c206f6620746800",
    ];
    // const ibcBallot = await IbcBallot.deploy(proposalNames, process.env.OP_DISPATCHER);

    // console.log("IbcBallot address:", ibcBallot.target);
    const tokenURI =
        "https://cdn.discordapp.com/attachments/841255110721929216/1092765295388676146/bc19-4725-b503-d375e88692b3.png?ex=6581777d&is=656f027d&hm=39c445ad33e663dfa03c8c59a7f88a15cd02218490f97c5ec8ed96d11475c184&";

    const ibcNFT = await IbcProofOfVoteNFT.deploy(process.env.BASE_DISPATCHER, tokenURI);
    console.log("NFT address:", ibcNFT.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
