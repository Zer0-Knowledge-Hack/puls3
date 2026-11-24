# Mainnet readiness: what the 2026-10-25 audit leaves to do

The audit findings that are not code bugs (D-1, I-1, P-1) are tracked in
[#206](https://github.com/Zer0-Knowledge-Hack/puls3/issues/206). The code
findings of that issue are merged: I-2 (#288), E-2 (#289), E-5 (#333) and the
catalog-id part of I-1 (#381). This page is what remains, who decides it, and
how to do it. The full list of findings is the
[audit register](../audits/2026-10-25-smart-contract-audit.md).

Nothing here is needed on testnet. Every item marked **before mainnet** must be
done, or explicitly accepted by the maintainers, before a mainnet deploy.

## D-1: one key holds several roles (before mainnet)

### Roles today, on testnet

From [`contracts/deployments/testnet.json`](../../contracts/deployments/testnet.json):

| Role | Who | Power |
|---|---|---|
| Escrow `admin` | `GAFUY…` | allowed tokens, fee and treasury, limits, the identity-registry change (timelocked since E-2), the next admin |
| Reputation registry owner | `GAFUY…` | upgrades the contract, so any of its behaviour (timelocked since R-6) |
| Identity registry owner | `GBY33…` (the deployer) | only transfers or renounces ownership: the registry has no other owner-only function |
| Payee of the 8 seed agents | `GAFUY…` | receives their hire payments. Rebinding them to custodied wallets was **not run**: [#209](https://github.com/Zer0-Knowledge-Hack/puls3/issues/209) was closed as not planned, because `set_agent_wallet` needs the owner's signature and the owner key of agents 7–14 is not available |
| Agent wallets of Studio agents | the server, through agent custody | signs `submit` for its agent; see [ADR-0003](../adr/0003-payment-rail-and-custody.md) |

`GAFUY…` is a Stellar CLI identity on a maintainer's machine. One leaked key
would therefore give control of the escrow configuration and the reputation
registry, and the payments of the seed agents.

### Target on mainnet

1. **One key per role.** The escrow admin, the reputation owner and the
   identity owner are three different accounts. No admin or owner is ever an
   agent's payee.
2. **Admin and owners are multisig accounts, kept off the server.** A Stellar
   account with several signers and a threshold authorizes Soroban calls
   natively (`require_auth` checks the account's signers and its medium
   threshold), so no contract change is needed. A suggested start: 2 of 3
   maintainers, on hardware wallets.
3. **The deployer is throwaway.** The deploy scripts make the deploying
   identity the first admin and owner. On mainnet, deploy with a fresh
   identity, hand every role to its multisig, then remove the deployer's
   signing power.
4. **The server holds only agent keys**, never an admin or owner key. Agent
   custody stays as in ADR-0003 until builder-owned accounts replace it.

### Procedure

Run it on testnet first, end to end, and record the transaction hashes.

1. Create the three multisig accounts (`set_options`: add the signers, set the
   thresholds, set the master weight to 0 once the signers are confirmed).
2. Deploy with `scripts/deploy-testnet.sh` and
   `scripts/deploy-escrow-testnet.sh`, pointed at mainnet, from the throwaway
   identity.
3. Hand over each role. Both steps are on chain, and a mistyped address cannot
   take control, because the new holder must accept:
   - escrow: `set_admin(caller, new_admin)`, then `accept_admin(new_admin)`
     from the multisig (two-step since E-3, #205);
   - each registry: `transfer_ownership(new_owner, live_until_ledger)`, then
     `accept_ownership()` from the multisig.
4. Check: `admin()` on the escrow and the owner of each registry return the
   multisig addresses, and the throwaway identity has no signing power left.
5. Record the addresses, the thresholds (not the signers' secrets) and the
   transaction hashes in `contracts/deployments/mainnet.json`.

On testnet, the deployed contracts still run the WASM from before #205, so the
escrow there has the old single-step `set_admin`. A redeploy is needed anyway
to apply the merged contract fixes (see the register).

**Who decides:** the maintainers, who choose the signers and hold the keys.
Nobody else can run this, and no secret belongs in the repository or in an
issue.

## I-1: proof of control at registration (before mainnet: decide)

**Merged (#381):** who may hold a catalog id.

- **A Studio id** (`studio-<draftId>`) belongs to the wallet that owns the
  draft, known off chain. A squatter cannot take it, whether it registers
  before or after the builder.
- **Any other id**, such as the seed `agt-*`, belongs to the owner who
  registered it first.

Either way, a copy of an agent's metadata by another owner no longer takes over
its catalog entry, its hires or its payments.

**Left:** for ids outside the Studio, and for `agent_uri`, registration is
still first come, first served. Someone can register one before its real owner
does. That needs proof of control, which is a design choice, not a fix:

| Option | How it proves control | Cost |
|---|---|---|
| Signed manifest | the manifest at the URI is signed by the registering account | builders sign once more; works for Studio, where the server writes the manifest |
| `.well-known` record | the URI's host serves the registering address at a fixed path | only for agents on their own domain |
| Catalog allow rule | only Studio registrations, or reviewed ids, are listed | central; simple; matches the product today |

Studio agents are the common case today. Their URIs are content hashes, and
the catalog does not key on the URI, so the risk left is small. **Who decides:**
the maintainers, in an ADR, before external builders can register on mainnet.

## P-1: process gaps

| Gap | State | Next step | Who decides |
|---|---|---|---|
| `cargo audit` in CI | Done: weekly, non-gating, `--deny warnings` (#269, #286); each ignore has a reason and a way out (`contracts/.cargo/audit.toml`) | drop the ignores with the `soroban-sdk` bump (#295) | done |
| Fuzzing | Not started | property tests on the escrow state machine and amounts (`proptest` as a dev dependency), then `cargo fuzz` on the same entry points | the team, when it wants the CI time |
| Mutation testing | Not started | `cargo mutants` on the escrow, weekly and non-gating like `contracts-audit` | the team |
| Third-party audit | Not done | an external audit of the three contracts at the mainnet commit | budget: the maintainers |
| Bug bounty | Not done | a scoped program after the external audit | budget: the maintainers |

**Before mainnet:** the external audit. The other rows make it cheaper and
can start at any time.
