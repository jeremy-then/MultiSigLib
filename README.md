# MultiSigLib

`MultiSigLib` is a lightweight Solidity **library** that adds majority-vote membership management to your contracts. It encapsulates all multisig state in a single `State` struct and exposes simple methods to **vote to add** or **remove** members with a strict-majority threshold (`floor(n/2) + 1`). It emits events for off-chain indexing and supports versioning of the member set to guarantee unique vote keys.

## Features

- **Strict majority** threshold: `threshold = floor(membersCount / 2) + 1`
- **Add/Remove members** via voting
- **Double-vote protection** with per-proposal versioned keys
- **Minimum members guard** (≥ 3)
- **Event emission** for every important action
- **Stateless library** (all storage lives in your contract via `State`)
- **Composable**: host multiple independent multisigs in a single contract (e.g., `teamState`, `treasuryState`)

## Installation

Using **Foundry**:

> `forge install jeremy-then/MultiSigLib@main`

Or specifying a version:

> `forge install jeremy-then/MultiSigLib@v1.0.0`

### Import paths

- If your repo name is `multisig-lib`:
  ```solidity
  import "multisig-lib/src/MultiSigLib.sol";
  ```
- Optional short alias: this library ships a `remappings.txt` with `multisig/=src/`, so you can:
  ```solidity
  import "multisig/MultiSigLib.sol";
  ```

## Quick Start

Minimal consumer contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "multisig-lib/src/MultiSigLib.sol";

contract MyMultisig {

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

    function membersCount() external view returns (uint256) { return state.getMembersCount(); }
    function threshold()    external view returns (uint256) { return state.getThreshold(); }
    function version()      external view returns (uint256) { return state.getMultisigVersion(); }

}
```

### Constructor input

- Pass **≥ 3 unique, non-zero** addresses to `init`.
- The multisig **version** starts at `1`. Every add/remove increments the version.

### Events

- `NewMemberCandidateVoted(address candidate, address voter)`
- `NewMemberAdded(address member, uint256 multisigVersion)`
- `MemberRemovalVoted(address member, address voter)`
- `MemberRemoved(address member)`

These are emitted from the **consumer contract’s address** (since libraries run in the context of the caller).

## API

All functions are `internal`, called as `state.fn(...)` (except where noted for ambiguity):

- `init(State storage state, address[] memory initialMembers)`
- `voteToAddNewMember(State storage state, address candidate)`
- `voteToRemoveMember(State storage state, address member)`
- Views:
  - `isMember(State storage state, address who) -> bool` *(call as `MultiSigLib.isMember(state, who)` to avoid name clash with the internal mapping)*
  - `getMembersCount(State storage state) -> uint256`
  - `getThreshold(State storage state) -> uint256`
  - `getMultisigVersion(State storage state) -> uint256`
  - `getNewMemberVotesForCandidate(State storage state, address candidate) -> uint256`
  - `getRemoveMemberVotesForMember(State storage state, address member) -> uint256`
  - `getAddNewMemberProposedAtVersion(State storage state, address candidate) -> uint256`
  - `getRemoveMemberProposedAtVersion(State storage state, address member) -> uint256`

## Design Notes

- **State struct**: Libraries cannot store persistent state. The `State` struct lives in your contract and contains the mappings/counters.
- **Versioning**: Each proposal stores `proposedAtMultisigVersion` and uses `(voter, subject, version)` to create a unique vote key, so members can vote multiple times for the same member/candidate they voted before but after a successful version upgrade.
- **Threshold**: recalculated after every composition change (`floor(n/2)+1`).
- **Min members**: removal cannot finalize if it would drop below `3` members.

## Testing

### Run tests

```bash
forge test -vv
```

## License

MIT — see `LICENSE`.

## Contributing

- Open an issue for bugs or feature requests.
- PRs welcome (please include tests).
