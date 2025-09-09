// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library MultiSigLib {

    struct NewMemberVote {
        uint256 votes;
        uint256 proposedAtMultisigVersion;
        mapping(bytes32 => bool) memberVoted;
    }

    struct RemoveMemberVote {
        uint256 votes;
        uint256 proposedAtMultisigVersion;
        mapping(bytes32 => bool) memberVoted;
    }

    struct State {
        mapping(address => NewMemberVote) newMembersVotes;
        mapping(address => RemoveMemberVote) removeMemberVotes;
        mapping(address => bool) isMember;
        uint256 membersCount;
        uint256 threshold;
        uint256 multisigVersion;
    }

    uint256 private constant MINIMUM_MEMBERS_COUNT = 3;

    event NewMemberCandidateVoted(address indexed candidate, address indexed voter);
    event NewMemberAdded(address indexed member, uint256 multisigVersion);
    event MemberRemovalVoted(address indexed member, address indexed voter);
    event MemberRemoved(address indexed member);

    function init(State storage state, address[] memory initialMembers) internal {

        require(initialMembers.length >= MINIMUM_MEMBERS_COUNT, "Initial multisig should have at least 3 members.");
        state.multisigVersion = 1;
        uint256 n = initialMembers.length;

        for (uint256 i = 0; i < n; i++) {
            address member = initialMembers[i];
            require(member != address(0), "Not valid address (zero address).");
            require(!state.isMember[member], "There should be no duplicate members.");
            state.isMember[member] = true;
            state.membersCount++;
            emit NewMemberAdded(member, state.multisigVersion);
        }

        _updateThreshold(state);

    }

    function voteToAddNewMember(State storage state, address candidate) internal {

        require(state.isMember[msg.sender], "Sender is not a member.");
        require(candidate != address(0), "Not valid address (zero address).");
        require(!state.isMember[candidate], "Candidate is already a member.");

        NewMemberVote storage vote = state.newMembersVotes[candidate];
        if (vote.proposedAtMultisigVersion == 0) {
            vote.proposedAtMultisigVersion = state.multisigVersion;
        }

        bytes32 voteKey = _getVotingKey(msg.sender, candidate, vote.proposedAtMultisigVersion);
        require(!vote.memberVoted[voteKey], "Sender already voted for this candidate.");
        vote.votes++;
        vote.memberVoted[voteKey] = true;

        emit NewMemberCandidateVoted(candidate, msg.sender);

        if (vote.votes >= state.threshold) {
            state.membersCount++;
            state.isMember[candidate] = true;
            state.multisigVersion++;
            delete state.newMembersVotes[candidate];
            _updateThreshold(state);
            emit NewMemberAdded(candidate, state.multisigVersion);
        }

    }

    function voteToRemoveMember(State storage state, address member) internal {

        require(state.isMember[msg.sender], "Sender is not a member.");
        require(member != address(0), "Not valid address (zero address).");
        require(state.isMember[member], "Not a member.");

        RemoveMemberVote storage vote = state.removeMemberVotes[member];

        if (vote.proposedAtMultisigVersion == 0) {
            vote.proposedAtMultisigVersion = state.multisigVersion;
        }

        bytes32 voteKey = _getVotingKey(msg.sender, member, vote.proposedAtMultisigVersion);
        require(!vote.memberVoted[voteKey], "Sender already voted to remove this member.");
        vote.votes++;
        bool hasReachedThreshold = vote.votes >= state.threshold;

        if (hasReachedThreshold && ((state.membersCount - 1) < MINIMUM_MEMBERS_COUNT)) {
            revert("Cannot remove; would drop below minimum members. Add a member first.");
        }

        vote.memberVoted[voteKey] = true;
        emit MemberRemovalVoted(member, msg.sender);

        if (hasReachedThreshold) {
            state.membersCount--;
            state.isMember[member] = false;
            state.multisigVersion++;
            delete state.removeMemberVotes[member];
            _updateThreshold(state);
            emit MemberRemoved(member);
        }
        
    }

    function isMember(State storage state, address possibleMember) internal view returns (bool) {
        return state.isMember[possibleMember];
    }

    function getMembersCount(State storage state) internal view returns (uint256) {
        return state.membersCount;
    }

    function getThreshold(State storage state) internal view returns (uint256) {
        return state.threshold;
    }

    function getMultisigVersion(State storage state) internal view returns (uint256) {
        return state.multisigVersion;
    }

    function getAddNewMemberVotesForThisCandidate(State storage state, address candidate) internal view returns (uint256) {
        return state.newMembersVotes[candidate].votes;
    }

    function getRemoveMemberVotesForMember(State storage state, address member) internal view returns (uint256) {
        return state.removeMemberVotes[member].votes;
    }

    function getAddNewMemberProposedAtVersion(State storage state, address candidate) internal view returns (uint256) {
        return state.newMembersVotes[candidate].proposedAtMultisigVersion;
    }

    function getRemoveMemberProposedAtVersion(State storage state, address member) internal view returns (uint256) {
        return state.removeMemberVotes[member].proposedAtMultisigVersion;
    }

    function _updateThreshold(State storage state) private {
        state.threshold = state.membersCount / 2 + 1;
    }

    function _getVotingKey(address voter, address subject, uint256 proposedAtMultisigVersion) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(voter, subject, proposedAtMultisigVersion));
    }
}
