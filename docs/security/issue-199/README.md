# Issue #199 · R-1: one poisoned feedback can make `get_summary` revert

- **Issue:** [#199](https://github.com/Zer0-Knowledge-Hack/puls3/issues/199)
- **Source:** security audit of 2026-10-25, finding R-1 (Medium)
- **Status:** fixed in source on branch `fix/199-poisoned-feedback-summary`,
  submitted for review in a pull request. **Not deployed** (the testnet
  registry still runs the old WASM) and not merged
- **Contract:** `contracts/contracts/reputation-registry`

## Objective

Stop a single feedback record from making the Reputation Registry's
`get_summary` fail for an agent, without breaking normal averages, revocation
or the Stellar 8004 ABI.

## In one paragraph

`give_feedback` accepted values up to `±1e38`, but `get_summary` normalizes every
value to 18 decimals in an `i128` (max about `1.7e38`) and returned the overflow
as an error, failing the whole call. The fix bounds new values by their
normalized size (`MAX_ABS_WAD = 1e28`, `1e10` whole units), which also makes
cumulative overflow unreachable, and makes `get_summary` skip, without counting,
any stored record it cannot normalize or add.

## Documents

| Document | Contents |
|---|---|
| [01-current-implementation.md](01-current-implementation.md) | How feedback is written, revoked, read and summarized before the fix |
| [02-requirements-analysis.md](02-requirements-analysis.md) | Each #199 requirement against the code: initial state and evidence |
| [03-vulnerability-reproduction.md](03-vulnerability-reproduction.md) | Root cause, scenarios and the real reproduction output |
| [04-technical-design.md](04-technical-design.md) | Alternatives, the chosen bound and why it covers the cumulative case |
| [05-implementation.md](05-implementation.md) | Every change in the contract and why |
| [06-test-results.md](06-test-results.md) | New tests, proof that they catch the bug, acceptance commands |
| [07-security-review.md](07-security-review.md) | Abuse cases, overflow and revocation review, residual risks |
| [08-final-report.md](08-final-report.md) | Summary, acceptance criteria, pending work |

## Files involved

- `contracts/contracts/reputation-registry/src/lib.rs`: the fix
- `contracts/contracts/reputation-registry/src/test.rs`: regression tests
- `contracts/contracts/reputation-registry/test_snapshots/test/`: snapshots of the new tests
- `docs/adr/0002-agent-registry-on-soroban.md`: the Stellar 8004 deviation
