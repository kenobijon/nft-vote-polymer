// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./base/CustomChanIbcApp.sol";

/**
 * @title IbcBallot
 * @dev Implements voting process along with vote delegation,
 * and ability to send cross-chain instruction to mint NFT on counterparty
 */
contract IbcBallot is CustomChanIbcApp {
    struct Voter {
        uint256 weight; // weight is accumulated by delegation
        bool voted; // if true, that person already voted;
        address delegate; // person delegated to
        uint256 vote; // index of the voted proposal
        // additional
        bool ibcNFTMinted; // if true, we've gotten an ack for the IBC packet and cannot attempt to send it again;  TODO: implement enum to account for pending state
    }

    struct Proposal {
        // If you can limit the length to a certain number of bytes,
        // always use one of bytes1 to bytes32 because they are much cheaper
        bytes32 name; // short name (up to 32 bytes)
        uint256 voteCount; // number of accumulated votes
    }

    address public chairperson;

    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    event NFTAckReceived(address voter, address recipient, uint256 voteId);

    /**
     *
     * IBC storage variables
     *
     */
    constructor(bytes32[] memory proposalNames, IbcDispatcher _dispatcher) CustomChanIbcApp(_dispatcher) {
        chairperson = msg.sender;
        supportedVersions = ["1.0", "2.0"]; //TODO: add setter to update

        voters[chairperson].weight = 1;

        for (uint256 i = 0; i < proposalNames.length; i++) {
            // 'Proposal({...})' creates a temporary
            // Proposal object and 'proposals.push(...)'
            // appends it to the end of 'proposals'.
            proposals.push(Proposal({name: proposalNames[i], voteCount: 0}));
        }
    }

    /**
     * @dev Give 'voter' the right to vote on this ballot. May only be called by 'chairperson'.
     * @param voter address of voter
     */
    function giveRightToVote(address voter) public {
        require(msg.sender == chairperson, "Only chairperson can give right to vote.");
        // require(
        //     !voters[voter].voted,
        //     "The voter already voted."
        // );
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    /**
     * @dev Delegate your vote to the voter 'to'.
     * @param to address to which vote is delegated
     */
    function delegate(address to) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param proposal index of proposal in the proposals array
     */
    function vote(uint256 proposal) public {
        Voter storage sender = voters[msg.sender];
        // FOR TESTING ONLY
        sender.weight = 1;
        require(sender.weight != 0, "Has no right to vote");
        // require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = proposal;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposal].voteCount += sender.weight;
    }

    /**
     * @dev Computes the winning proposal taking all previous votes into account.
     * @return winningProposal_ index of winning proposal in the proposals array
     */
    function winningProposal() public view returns (uint256 winningProposal_) {
        uint256 winningVoteCount = 0;
        for (uint256 p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    /**
     * @dev Calls winningProposal() function to get the index of the winner contained in the proposals array and then
     * @return winnerName_ the name of the winner
     */
    function winnerName() public view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }

    /**
     * @param voterAddress the address of the voter
     * @param recipient the address on the destination (Base) that will have NFT minted
     */
    function sendMintNFTMsg(bytes32 channelId, uint64 timeoutSeconds, address voterAddress, address recipient)
        external
        payable
    {
        require(voters[voterAddress].ibcNFTMinted == false, "Already has a ProofOfVote NFT minted on counterparty");

        uint256 voteId = voters[voterAddress].vote;
        bytes memory payload = abi.encode(voterAddress, recipient, voteId);

        uint64 timeoutTimestamp = uint64((block.timestamp + timeoutSeconds) * 1000000000);

        dispatcher.sendPacket(channelId, payload, timeoutTimestamp);
    }

    // Utility functions

    function resetVoter(address voterAddr) external {
        voters[voterAddr].ibcNFTMinted = false;
        voters[voterAddr].voted = false;
        voters[voterAddr].vote = 0;
        voters[voterAddr].weight = 0;
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and returns and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *
     * @param packet the IBC packet encoded by the source and relayed by the relayer.
     */
    function onRecvPacket(IbcPacket memory packet)
        external
        override
        onlyIbcDispatcher
        returns (AckPacket memory ackPacket)
    {
        recvedPackets.push(packet);
        (address voterAddr, address recipientAddr, uint256 voteId) =
            abi.decode(packet.data, (address, address, uint256));

        return AckPacket(true, abi.encode(voterAddr, recipientAddr, voteId));
    }

    /**
     * @dev Packet lifecycle callback that implements packet acknowledgment logic.
     *      MUST be overriden by the inheriting contract.
     *
     * @param ack the acknowledgment packet encoded by the destination and relayed by the relayer.
     */
    function onAcknowledgementPacket(IbcPacket calldata, AckPacket calldata ack) external override onlyIbcDispatcher {
        ackPackets.push(ack);

        (address voterAddr, address recipientAddr, uint256 voteId) = abi.decode(ack.data, (address, address, uint256));
        emit NFTAckReceived(voterAddr, recipientAddr, voteId);
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
