// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MultiSigLib
 * @dev A library to manage a multisignature wallet with member addition and removal functionalities.
 * The library allows members to vote on adding new members or removing existing ones, with a dynamic threshold based on the current number of members.
 * The multisig version increments with each successful addition or removal of a member.
 */
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

    /**
     * @dev Initialize the multisig state with the initial members.
     * Requirements:
        * - The initial members list must contain at least 3 members.
        * - No duplicate members are allowed.
        * - No zero address is allowed as a member.
    * Emits a {NewMemberAdded} event for each initial member added.
    * Sets the initial threshold based on the number of members.
     */
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

    /**
     * @dev Vote to add a new member to the multisig.
     * Requirements:
        * - The sender must be a member.
        * - The candidate address must be valid (not zero).
        * - The candidate must not be already a member.
    * Emits a {NewMemberCandidateVoted} event when a vote is cast.
    * Emits a {NewMemberAdded} event when the candidate is added as a member.
    * If the candidate receives enough votes to meet the threshold, they are added as a member,
        the multisig version is incremented, and the threshold is updated.
    * Each member can vote only once per candidate per multisig version.
     */
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

    /**
     * @dev Vote to remove an existing member from the multisig.
     * Requirements:
        * - The sender must be a member.
        * - The member address must be valid (not zero).
        * - The member must be an existing member.
        * - Removing the member must not drop the total members below the minimum required (3).
    * Emits a {MemberRemovalVoted} event when a vote is cast.
    * Emits a {MemberRemoved} event when the member is removed.
    * If the member receives enough votes to meet the threshold, they are removed as a member,
        the multisig version is incremented, and the threshold is updated.
    * Each member can vote only once per member per multisig version.
    */
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

    /**
     * @dev Update the voting threshold based on the current number of members.
     */
    function _updateThreshold(State storage state) private {
        state.threshold = state.membersCount / 2 + 1;
    }

    /**
     * @dev Generate a unique voting key for a voter and subject (candidate/member) b`ased on the multisig version.
     * This ensures that votes are unique per member per subject per multisig version.
     * Ideal for members to vote again after a candidate/member has been added/removed and a new version is in place,
        * useful to avoid a 'sender already voted' error when the same member wants to again for the same subject in a new version.
     */
    function _getVotingKey(address voter, address subject, uint256 proposedAtMultisigVersion) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(voter, subject, proposedAtMultisigVersion));
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

}
