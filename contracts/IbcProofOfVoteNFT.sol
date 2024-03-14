// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";

import "./base/CustomChanIbcApp.sol";

contract IbcProofOfVoteNFT is ERC721, CustomChanIbcApp {
    uint256 public currentTokenId;

    string public tokenURIPolyVote;

    constructor(IbcDispatcher _dispatcher, string memory _tokenURIPolyVote)
        ERC721("PolyVoter", "POLYV")
        CustomChanIbcApp(_dispatcher)
    {
        tokenURIPolyVote = _tokenURIPolyVote;
    }

    function mint(address recipient) public returns (uint256) {
        currentTokenId += 1;
        uint256 tokenId = currentTokenId;
        _safeMint(recipient, tokenId);
        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(tokenId <= currentTokenId, "ERC721Metadata: URI query for nonexistent token");

        return tokenURIPolyVote;
    }

    function updateTokenURI(string memory _newTokenURI) public {
        tokenURIPolyVote = _newTokenURI;
    }

    event NFTAckReceived(address voter, address recipient, uint256 voteId);

    /**
     *
     * IBC storage variables
     *
     */

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and returns and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *
     * @param packet the IBC packet encoded by the source and relayed by the relayer.
     */
    function onRecvPacket(IbcPacket calldata packet)
        external
        override
        onlyIbcDispatcher
        returns (AckPacket memory ackPacket)
    {
        recvedPackets.push(packet);

        (address decodedVoter, address decodedRecipient, uint256 decodedVoteId) =
            abi.decode(packet.data, (address, address, uint256));

        uint256 voteNFTId = mint(decodedRecipient);

        bytes memory ackData = abi.encode(decodedVoter, voteNFTId, decodedVoteId);

        return AckPacket(true, ackData);
    }

    /**
     * @dev Packet lifecycle callback that implements packet acknowledgment logic.
     *      MUST be overriden by the inheriting contract.
     *
     * @param ack the acknowledgment packet encoded by the destination and relayed by the relayer.
     */
    function onAcknowledgementPacket(IbcPacket calldata packet, AckPacket calldata ack)
        external
        override
        onlyIbcDispatcher
    {
        // TODO add error
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and return and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *      NOT SUPPORTED YET
     *
     * @param packet the IBC packet encoded by the counterparty and relayed by the relayer
     */
    function onTimeoutPacket(IbcPacket calldata packet) external override onlyIbcDispatcher {
        timeoutPackets.push(packet);
        // do logic
    }
}
