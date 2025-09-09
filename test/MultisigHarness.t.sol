// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiSigLib.sol";

contract MultisigHarness {

    using MultiSigLib for MultiSigLib.State;
    MultiSigLib.State private state;

    constructor(address[] memory initialMembers) {
        state.init(initialMembers);
    }

    function voteAdd(address candidate) external {
        state.voteToAddNewMember(candidate);
    }

    function voteRemove(address member) external {
        state.voteToRemoveMember(member);
    }

    function isMember(address who) external view returns (bool) {
        return MultiSigLib.isMember(state, who);
    }

    function membersCount() external view returns (uint256) {
        return state.getMembersCount();
    }

    function threshold() external view returns (uint256) {
        return state.getThreshold();
    }

    function version() external view returns (uint256) {
        return state.getMultisigVersion();
    }
}

contract MultiSigLibTest is Test {

    address M1 = address(0x86fEa303737F5219d7b5E4f30Cb7268Bec1775Fa); // Generated with seed 'member1'
    address M2 = address(0xbD405055317EF6089a771008453365060BB97aC1); // Generated with seed 'member2'
    address M3 = address(0xeb1b36D046AC9d13E7547cd936D135fd9e8542Cd); // Generated with seed 'member3'
    address M4 = address(0xCbB27fd0bFbA64828063F11222AF8E8fe899D6CD); // Generated with seed 'member4'
    address NON = address(0x775dd06aAEd73791B44bE3d3f16fE5571B1709fA); // Generated with seed 'nonmember'
    address randomAddress = address(0xe899D4fE48da746223F9Ad56f1511FB146EC86fF); // Generated with seed 'randomAddress'

    MultisigHarness multisigHarness;

    function setUp() public {
        address[] memory members = new address[](3);
        members[0] = M1;
        members[1] = M2;
        members[2] = M3;
        multisigHarness = new MultisigHarness(members);
    }

    function testInitBasics() public {
        assertEq(multisigHarness.membersCount(), 3);
        assertEq(multisigHarness.threshold(), 2);
        assertTrue(multisigHarness.isMember(M1));
        assertTrue(multisigHarness.isMember(M2));
        assertTrue(multisigHarness.isMember(M3));
        assertFalse(multisigHarness.isMember(M4));
    }

    function testAddMemberReachesThreshold() public {
        vm.prank(M1);
        multisigHarness.voteAdd(M4);
        assertEq(multisigHarness.membersCount(), 3);
        assertFalse(multisigHarness.isMember(M4));

        vm.prank(M2);
        multisigHarness.voteAdd(M4);
        assertEq(multisigHarness.membersCount(), 4);
        assertTrue(multisigHarness.isMember(M4));
        assertEq(multisigHarness.threshold(), 3);
    }

    function testCannotDoubleVoteForCandidate() public {
        vm.startPrank(M1);
        multisigHarness.voteAdd(M4);
        vm.expectRevert(bytes("Sender already voted for this candidate."));
        multisigHarness.voteAdd(M4);
        vm.stopPrank();
    }

    function testRemoveMemberBelowMinimum() public {
        vm.prank(M1);
        multisigHarness.voteRemove(M3);
        vm.expectRevert(bytes("Cannot remove; would drop below minimum members. Add a member first."));
        vm.prank(M2);
        multisigHarness.voteRemove(M3);
    }

    function testRemoveMemberAfterAddingFourth() public {

        vm.prank(M1);
        multisigHarness.voteAdd(M4);

        vm.prank(M2);
        multisigHarness.voteAdd(M4);

        assertTrue(multisigHarness.isMember(M4));
        assertEq(multisigHarness.membersCount(), 4);
        assertEq(multisigHarness.threshold(), 3);

        vm.prank(M1);
        multisigHarness.voteRemove(M3);

        vm.prank(M2);
        multisigHarness.voteRemove(M3);

        vm.prank(M4);
        multisigHarness.voteRemove(M3);

        assertFalse(multisigHarness.isMember(M3));
        assertEq(multisigHarness.membersCount(), 3);
        assertEq(multisigHarness.threshold(), 2);
    }

    function testVersionIncrementsOnCompositionChange() public {

        uint256 v1 = multisigHarness.version();

        vm.prank(M1);
        multisigHarness.voteAdd(M4);

        vm.prank(M2);
        multisigHarness.voteAdd(M4);

        uint256 v2 = multisigHarness.version();

        assertEq(v2, v1 + 1);

        vm.prank(M1);
        multisigHarness.voteRemove(M3);

        vm.prank(M2);
        multisigHarness.voteRemove(M3);

        vm.prank(M4);
        multisigHarness.voteRemove(M3);

        uint256 v3 = multisigHarness.version();
        assertEq(v3, v2 + 1);

    }

    function testOnlyMembersCanVote() public {

        vm.expectRevert(bytes("Sender is not a member."));
        vm.prank(NON);
        multisigHarness.voteAdd(M4);

        vm.expectRevert(bytes("Sender is not a member."));
        vm.prank(NON);
        multisigHarness.voteRemove(M1);

    }

    function testRejectZeroAddressWhenVotingToAddANewMember() public {
        vm.prank(M1);
        vm.expectRevert(bytes("Not valid address (zero address)."));
        multisigHarness.voteAdd(address(0));
    }

    function testRejectZeroAddressWhenVotingToRemove() public {
        vm.prank(M1);
        vm.expectRevert(bytes("Not valid address (zero address)."));
        multisigHarness.voteRemove(address(0));
    }   

    function testAlreadyAMember() public {
        vm.prank(M1);
        vm.expectRevert(bytes("Candidate is already a member."));
        multisigHarness.voteAdd(M2);
    }

    function testNotAMember() public {
        vm.prank(M1);
        vm.expectRevert(bytes("Not a member."));
        multisigHarness.voteRemove(address(randomAddress));
    }

}
