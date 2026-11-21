# Security audit of 2026-10-25: findings register

- **Scope:** Soroban contracts (escrow, identity registry, reputation registry),
  the Serverpod relay, and how the Flutter app uses them.
- **Result:** no critical flaw; the escrow is sound. 15 findings, concentrated
  in reputation griefing (R-1, R-3), product and design gaps (E-1, E-2),
  operations (D-1), identity (I-1, I-2) and hygiene (R-4, R-5, R-6, E-3, E-4,
  E-5, P-1). Follow-up work confirmed R-1 and R-3 with proof-of-concept tests.
- **Tracking:** [#207](https://github.com/Zer0-Knowledge-Hack/puls3/issues/207)
  lands this file.

## What this file is, and what it is not

The full audit report was produced as a conversation document and has never been
in the repository. This file is **not** that report. It is the register of its
findings, built only from sources in this repository: the follow-up issues
(each opened from the report, with the finding ID, severity, problem and fix)
and the commits that fixed them. Nothing here is rewritten from memory or
inferred.

What the original report has and this file does not: methodology, evidence
sections (for example the proof of concept in its section 6.2, cited by #199
and #200), and the full reasoning for each severity. Where the follow-ups do
not state something, this file says so. If the original turns up, add it next
to this file as `2026-10-25-smart-contract-audit-report.md` and keep the IDs
below unchanged.

## How to cite a finding

Use the ID as written here, with the date: `audit 2026-10-25, R-1`. The IDs are
stable: issues, commits, code comments and tests already use them (for example
`contracts/.cargo/audit.toml` cites P-1, and `contracts/contracts/escrow/src/lib.rs`
cites E-2 and E-5).

## Findings

The report counts 15 findings. R-2 is one finding, split in two issues for its
two halves (R-2a, R-2b).

Severity is the one stated in the follow-up issue. "Not stated" means the issue
refers back to the report without giving one.

| ID | Severity | Finding | Tracking | Fix on `main` | State |
|---|---|---|---|---|---|
| R-1 | Medium | One feedback with a huge `value` makes `get_summary` revert for any client list that includes its author | [#199](https://github.com/Zer0-Knowledge-Hack/puls3/issues/199) | `d067e33` ([#238](https://github.com/Zer0-Knowledge-Hack/puls3/pull/238)) | Fixed in source |
| R-2a | Medium | "Only a paying customer can rate" is enforced by the backend only; a rating carries no link to a paid hire | [#201](https://github.com/Zer0-Knowledge-Hack/puls3/issues/201) | `777be84` ([#239](https://github.com/Zer0-Knowledge-Hack/puls3/pull/239)) | Fixed |
| R-2b | Medium | The served score is computed off chain, and nothing proved the server feeds it every on-chain record | [#202](https://github.com/Zer0-Knowledge-Hack/puls3/issues/202) | `59b2bcb` ([#230](https://github.com/Zer0-Knowledge-Hack/puls3/pull/230)) | Fixed |
| R-3 | Low | An agent can rate itself through its payout wallet: the self-feedback check only looks at the owner | [#200](https://github.com/Zer0-Knowledge-Hack/puls3/issues/200) | `7e0e606` ([#237](https://github.com/Zer0-Knowledge-Hack/puls3/pull/237)) | Fixed in source |
| R-4 | Low | `get_summary` loops without a bound over per-client records, and every read extends TTL | [#205](https://github.com/Zer0-Knowledge-Hack/puls3/issues/205) | `5c4ed3a` ([#241](https://github.com/Zer0-Knowledge-Hack/puls3/pull/241)) | Fixed in source |
| R-5 | Low | `append_response` is open to anyone, with no cap | [#205](https://github.com/Zer0-Knowledge-Hack/puls3/issues/205) | `5c4ed3a` ([#241](https://github.com/Zer0-Knowledge-Hack/puls3/pull/241)) | Fixed in source |
| R-6 | Low | Upgrade `propose` / `cancel` / `execute` emit no events, and a proposal never expires | [#205](https://github.com/Zer0-Knowledge-Hack/puls3/issues/205) | `5c4ed3a` ([#241](https://github.com/Zer0-Knowledge-Hack/puls3/pull/241)) | Fixed in source |
| E-1 | Medium | The client can read the full output before paying, then reject for a full refund | [#204](https://github.com/Zer0-Knowledge-Hack/puls3/issues/204) | `b4a34e8` ([#240](https://github.com/Zer0-Knowledge-Hack/puls3/pull/240)) | Fixed |
| E-2 | Not stated | `set_identity_registry` is instant and single-key: a compromised admin can redirect future payments | [#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206) | `a6bb6ac` ([#289](https://github.com/Zer0-Knowledge-Hack/puls3/pull/289)) | Fixed in source |
| E-3 | Low | `set_admin` is single-step (a typo loses control), and `set_treasury` applies to jobs in flight | [#205](https://github.com/Zer0-Knowledge-Hack/puls3/issues/205) | `5c4ed3a` ([#241](https://github.com/Zer0-Knowledge-Hack/puls3/pull/241)) | Fixed in source |
| E-4 | Not stated | Not described in any follow-up issue | none | none | Unknown: needs the original report |
| E-5 | Not stated | The persistent TTL (about 60 days) is not tied to `max_expiry` | [#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206) | [#333](https://github.com/Zer0-Knowledge-Hack/puls3/pull/333), in review | Open |
| D-1 | Not stated (mainnet blocker) | One key is escrow admin, reputation owner and agent 7's provider wallet, and agent keys are custodied by the server | [#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206) | none | Open |
| I-1 | Not stated | Agent URI squatting: registration has no proof of control | [#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206) | none | Open |
| I-2 | Not stated | Permissionless registration feeds `catalog.list()`, which every `createHire` read | [#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206) | `22a9b3a` ([#288](https://github.com/Zer0-Knowledge-Hack/puls3/pull/288)) | Fixed |
| P-1 | Not stated | Process gaps: no third-party audit, no fuzzing or mutation testing, no `cargo audit` in CI, no bug bounty | [#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206) | `cargo audit`: `0d146ac` ([#269](https://github.com/Zer0-Knowledge-Hack/puls3/pull/269)), `21b9252` ([#286](https://github.com/Zer0-Knowledge-Hack/puls3/pull/286)) | Partly done |

**Fixed** means merged and running: the server and domain changes (R-2a, R-2b,
E-1, I-2) are in the deployed server. **Fixed in source** means a contract
change that is merged, but the contracts on testnet still run the WASM from
before it: it applies once they are redeployed or upgraded. The deployed hashes are in
[`contracts/deployments/testnet.json`](../../contracts/deployments/testnet.json).

The decision on where the reputation formula runs (R-2a, R-2b, R-4) is recorded
in [ADR-0008](../adr/0008-reputation-formula-off-chain.md) and tracked in
[#203](https://github.com/Zer0-Knowledge-Hack/puls3/issues/203).

## Detailed write-ups

- R-1: [`docs/security/issue-199/`](../security/issue-199/README.md)
- R-2a: [`docs/security/issue-201/`](../security/issue-201/README.md)
- R-2b: [`docs/domain/reputation.md`](../domain/reputation.md) explains how to
  recompute a served rating from the chain.

## Still open before mainnet

D-1, I-1, E-5 (in review), the rest of P-1, and the redeploy that puts the
"fixed in source" rows on chain. They are tracked in
[#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206). E-4 needs the
original report.

What each open item needs, who decides it, and the key-separation procedure for
D-1 are in [mainnet readiness](../security/mainnet-readiness.md).
