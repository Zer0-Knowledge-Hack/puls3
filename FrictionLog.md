# Friction log: building puls3 on Stellar (HackMeridian 2026)

Team Zer0-Knowledge. puls3 started before HackMeridian (first commit
2026-09-14), so this log covers the whole build, Sept–Nov 2026, not only the
event weekend. Time estimates are approximate. They come from commit and PR
dates and from our working sessions, not from time tracking.

## What we built

puls3 is an AI agent hub on Stellar. Builders create agents in a Studio and
deploy them; consumers hire them and pay in USDC.

- **Identity and reputation:** each agent is an on-chain identity in a
  Soroban registry that follows ERC-8004. A reputation registry holds the
  consumers' ratings. The app's rating screen is in review (PR #217).
- **Payment:** each hire is a job in a Soroban escrow that follows ERC-8183.
  The consumer funds it in USDC, the agent submits its result, and the
  consumer approves or rejects. Deadlines move the money on their own: a
  refund if no result arrives in time, a release to the agent if the
  approval window passes.
- **Server:** Serverpod (Dart) with PostgreSQL. It runs the agents with
  hosted LLMs and holds custodied agent wallets. Signing the agent's escrow
  `submit` with that wallet is in review (PR #213).
- **App:** Flutter Web with Freighter.

## Stellar tools we used, and how

| Tool | How we used it |
|---|---|
| **Soroban smart contracts** (`soroban-sdk` 28, Rust) | We wrote three contracts: `identity-registry` (ERC-8004 style), `reputation-registry` and `escrow` (ERC-8183 style: create, fund, submit, complete or reject, claim refund, pull-payment balances). All three are deployed on testnet. |
| **Stellar CLI** | We used it to build and deploy the contracts, to seed the demo agents, and to read contract state (for example the escrow's `approval_window`). We also used it for testnet identities, Friendbot funding, USDC trustlines, and a DEX path payment that bought testnet USDC. |
| **Stellar Asset Contract (SAC) + Circle testnet USDC** | The escrow moves USDC through its SAC. Early proofs used a throwaway asset (`PUSDC`) with its own SAC. |
| **Stellar RPC** | The server and the spikes call it over plain HTTP. We used `simulateTransaction`, `sendTransaction`, `getTransaction` (with `xdrFormat: "json"`), `getEvents`, `getLatestLedger` and `getLedgers`. |
| **Horizon** | The app reads wallet balances from it. We also used it to check transaction effects while debugging. |
| **`stellar_dart` 2.3.0** (server) | Keys and ed25519 signing, strkeys, transaction envelopes, SEP-10 challenges, and signing with custodied agent keys. |
| **`stellar_flutter_sdk` 3.8.0** (app) | Builds transactions and authorization preimages for Freighter, and reads Horizon balances. |
| **Freighter** | Connects the wallet, signs transactions (`signTransaction`), signs Soroban authorization entries (`signAuthEntry`), and signs the SEP-10 sign-in challenge. |
| **SEP-10** | Wallet sign-in: a challenge transaction signed by the wallet, then a server session. |
| **x402 (`@x402/fetch`, `@x402/stellar`)** | Only as a reference. We wrote a Dart x402 client (spike #164) and compared it against the official TypeScript client on testnet. |
| **stellar.expert** | Links to on-chain evidence in PRs and docs. |
| **Stellar Raven** | Research search, for example to check whether ERC-8183 already existed on Soroban (2026-09-30). |
| **Stellar MCP servers** | We did not connect one to our coding agents. We reviewed `stellar-agent-search` (MCP) and the Stellar AI Agent Kit during research. |

## Friction points

### 1. Soroban authorization entries changed under us (`ADDRESS` vs `ADDRESS_V2`)

- **What happened:**
  - On 2026-09-30 SDF testnet ran protocol 29. Simulating a native SAC `transfer` there returned **only `ADDRESS_V2`** credentials (CAP-71). The JS SDK says `useUpgradedAuth=false` is a no-op from protocol 28, so we could not ask for the legacy format.
  - `ADDRESS_V2` is signed over a different preimage, `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS`. The Freighter guide documented the legacy one.
  - On 2026-11-05 testnet ran protocol 30, and a USDC SAC `transfer` simulation returned legacy `ADDRESS` (type 1) again.
- **Cost:** about 1–2 days in the Flutter wallet spike (#70), plus some hours later.
- **Fix:**
  - We support both credential types and build the preimage for each one.
  - We tested both byte for byte against `@stellar/stellar-sdk`.
- **Would have helped:** a changelog note on when RPC returns each credential type, and a Freighter `signAuthEntry` example for `ADDRESS_V2`.

### 2. No Flutter-free Stellar SDK with current Soroban auth for a Dart server

- **What happened:**
  - `stellar_flutter_sdk` imports `package:flutter/services.dart` (`dart:ui`), so `dart run` on the server does not compile.
  - `stellar_dart` 2.3.0 runs on the Dart VM. However:
    - its `SorobanCredentialsType` stops at `address`;
    - its `EnvelopeType` stops at 9;
    - it has no `HashIdPreimage` for Soroban authorization.
- **Cost:** it shaped the server design (ADR-0001: plain HTTP RPC instead of an SDK), and it took about 380 lines of hand-written XDR in the x402 spike.
- **Fix:**
  - On the server we call RPC over plain HTTP and use `stellar_dart` for keys and envelopes.
  - We wrote the `ADDRESS_V2` entry and its signing payload by hand.
- **Would have helped:** a pure-Dart SDK, or a Flutter-free entry point of `stellar_flutter_sdk`, kept current with CAP-71.

### 3. x402 on Stellar: no Dart client, and the payload format is only in TypeScript

- **What happened:**
  - The x402 packages are TypeScript only.
  - We did not find the facilitator endpoints or the exact `PAYMENT-SIGNATURE` payload in the x402 quickstart. To find the payload we read the `@x402/stellar` source. It is a base64 JSON with `accepted` echoed back, and an unsigned envelope whose source is the all-zero account, re-simulated after signing.
- **Cost:** about 1–2 hours of reading source in spike #164. The Dart client then worked on the first live run.
- **Fix:**
  - We mirrored `ExactStellarScheme` in Dart.
  - We kept a reference run with `@x402/fetch` to tell server problems apart from client problems.
- **Would have helped:** a short x402-on-Stellar spec page with the payload and facilitator API, independent of the TypeScript SDK.

### 4. An x402 provider charged and then timed out

- **What happened:**
  - Paying a third-party x402 API on testnet (TIA), 3 of 6 paid calls returned a Vercel `504 FUNCTION_INVOCATION_TIMEOUT` **after** the USDC transfer had settled.
  - The official TypeScript client hit it 2 of 3 times, so it was not our client.
  - Without a `PAYMENT-RESPONSE` header, the payer cannot tell from HTTP alone whether it paid.
- **Cost:** about 30 minutes to confirm. 0.45 testnet USDC was paid for no data.
- **Fix:**
  - We recorded it for the runtime. After a 5xx, check the chain before retrying, or the agent pays twice.
  - We are reporting it to the provider.
- **Would have helped:** guidance in the x402 docs on settle-then-serve failures and on how to reconcile them.

### 5. Testnet USDC is hard to get from scripts

- **What happened:** Circle's faucet is a web form, so tests and seeding scripts cannot use it.
- **Cost:** a few hours over the project.
- **Fix:**
  - Early proofs used a throwaway asset with its own SAC.
  - Later we bought testnet USDC with Friendbot XLM on the testnet DEX (`path-payment-strict-receive`), which needs no captcha.
- **Would have helped:** a scriptable testnet USDC faucet, or a documented testnet DEX route.

### 6. Escrow timing parameters fail late and quietly

- **What happened:**
  - Our escrow rejects `submit` with `SubmitTooLate` unless `now + approval_window < expired_at`. The testnet escrow's `approval_window` is 86400 s.
  - Our docs set the hire's job duration to 86400 s too, so every agent `submit` would fail in simulation.
  - This was our configuration bug, not a Stellar bug. RPC does return the contract error (`Error(Contract, #106)`) in the simulation's diagnostic events. But it is a number inside a string, and our server logged it as a generic chain error. We found the cause by reading the contract and querying `approval_window` with the CLI.
- **Cost:** about 1 hour once we looked for it. Nobody had noticed it in review before.
- **Fix:**
  - The job duration is now 172800 s, and the docs state the rule.
- **Would have helped:** a structured contract error (contract id plus code) in the `simulateTransaction` response, so clients can map it to the contract's error enum without parsing diagnostic event strings.

### 7. State archival and TTL

- **What happened:** new persistent entries (the registry's URI index, the escrow's claimable balances) needed explicit TTL extension. Otherwise they could be archived.
- **Cost:** two fixes, on 2026-09-25 and 2026-10-06 (#105). Each was a small change plus tests.
- **Fix:** we extend the TTL where each entry is written.
- **Would have helped:** a checklist in the contract docs: "every new persistent key needs a TTL plan".

### 8. Being compatible with Stellar 8004 is not enough to be discoverable

- **What happened:**
  - Our identity registry follows the ERC-8004 interface used by Stellar 8004.
  - Ecosystem tools (the explorer and the agent-search MCP) index only the Stellar 8004 contracts, so puls3 agents do not show up there.
- **Cost:** about a day of review (ADR-0002 drop-in review).
- **Fix:** we documented the gap. Joining the shared registry is a mainnet decision.
- **Would have helped:** an indexer that any ERC-8004-compatible registry can opt into.

### 9. Small setup issues

- **Stellar CLI from WSL:** we call `stellar.exe` at a Windows path with spaces, and its identities live in the Windows profile.
- **Testnet resets:** some older CLI identities now return 404 on Horizon, which looks like a testnet reset. We fund new ones with `stellar keys generate --fund`.
- **RPC history:** RPC keeps about 7 days of transactions, so the server must check a payment right after it happens.
- **Cost:** minutes each, but they add up.

## What worked well

- **Soroban contracts and tests in Rust:** the SDK, the test environment and the error enums were reliable. The three contracts went from scaffold (2026-09-23) to testnet in about three weeks: identity on 2026-09-25, escrow on 2026-10-05, reputation on 2026-10-13.
- **Stellar CLI:**
  - deploy, invoke and read worked well, including `--send no` for read-only calls;
  - `keys generate --fund` and the classic operations (trustlines, path payments) made testnet setup fast.
- **Plain JSON-RPC:**
  - `getTransaction` with `xdrFormat: "json"` and the SAC `transfer` events made payment verification simple from Dart, with no SDK;
  - `simulateTransaction` caught auth and balance problems before we signed anything.
- **SAC:** one `transfer` interface for classic USDC and test assets, so changing the asset was a config change.
- **Freighter:** `signTransaction`, `signAuthEntry` and the SEP-10 challenge all worked from Flutter Web once the preimage was right.
- **Fees and settlement:** low fees and fast ledgers (about 5 s). In x402 the facilitator paid the fee, so the paying account needed USDC but no XLM for fees.

## What would have made Stellar development easier

1. A Dart SDK (no Flutter dependency) that tracks protocol changes like CAP-71.
2. One page on Soroban authorization credentials. It should say:
   - which type RPC returns, and when;
   - how each one is signed;
   - a wallet example for each type.
3. An x402-on-Stellar protocol page: the payload format, the facilitator API, and how to handle a lost response after settlement.
4. A scriptable testnet USDC faucet.
5. Structured contract errors in `simulateTransaction` results.
6. A shared ERC-8004 indexer for agent discovery that any compatible registry can join.
