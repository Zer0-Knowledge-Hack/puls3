# #424: remaining npm SDK checks and errors

Objective: close the signing checks, flow, session, error and server gaps of #424 in `puls3_sdk_ts` (and one in `puls3_server`).
Branch: `fix/424-npm-sdk-checks` (worktree `puls3-worktrees/424-npm-sdk-checks`, from `cb69502`). Delivery: `ask-on-risk`. Runner: `npm run check && npm test` in `puls3_sdk_ts`; `dart test` in `puls3_server`.

## Specs

Quoted from #424 and its comments.

- **S1** Signing checks (ADR-0010 D3 rule 4): "`give_feedback`: the score (argument 2) is the one the caller passed to `rate`." "`register_full`: the agent URI and metadata are the draft's." "`fund`: `max_fee_bps` (last argument) is bounded." Acceptance: "Each check in deliverable 1 refuses a mismatching envelope with `SigningRefused` and a test per check; envelopes the Dart server builds are still accepted." (`reject` reason hash and `register_full` metadata are already done in `89c541a`.) Assumption: the fee bound is a `maxFeeBps` on `Puls3Network`, never above the escrow's `MAX_FEE_BPS = 1_000`.
- **S2** "A retried `hire()` waits blind. When `createHire` returns no `create_job` preparation (one is already underway), a `create_job` that then fails on chain ends as `Puls3Timeout`, not `ChainSubmissionFailed`."
- **S3** "`hire()` can return an unfunded hire. After the fund step it does not check that the hire is `funded`."
- **S4** "Session lock race. The stale-lock takeover in `session.ts` is check-then-remove: two processes can both take the lock and present the same refresh token, which revokes the session."
- **S5** "Typed errors. A 200 with a non-JSON body throws a raw `SyntaxError` (`transport.ts`); a non-integer `maxPrice` throws `RangeError` instead of `InvalidArgument`; a signer or protocol failure during `KeySession` login becomes a generic 401."
- **S6** "The Soroban RPC reads have no timeout (`chain_reader.ts`), so a hung RPC hangs `hire` and `deploy` past `stepTimeoutMs`."
- **S7** "Node 20: `npm test` uses a glob in `node --test`, which needs Node 21, while `engines` says `>=20`." Acceptance: "`npm run check` and `npm test` pass on Node 20 and 22."
- **S8** "a Studio draft whose name matches an agent already registered fails `prepareDeploy` with `ChainUnavailable` (`simulationFailed`), which does not say why." Acceptance: "The duplicate-name deploy returns a typed error naming the conflict." Note: the contract refuses a duplicate URI (`UriAlreadyRegistered = 100`), not a name.
- **S9** "make the reviewed result required (or the default) for `approve`, for example `approve(hireId, { result })` with the server-trusting path as an explicit opt-out, so callers are safe by default." Decision (L2): required, with an explicit opt-out; ships as 0.2.0.
- **S10** "`hire({ maxReserve })` is accepted, but `createHire` always sends `subcontractReserve: null` (`sdk.ts`), so the option never applies. Either wire it to `createHire` or drop it until reserves are in scope." Choice: wire it (the server accepts `subcontractReserve`).
- Acceptance shared by S2-S7: "Deliverables 2 to 7 each have a test that fails before the fix."

## Tasks

| ID | Specs | Route | Risk | Status | Commit |
|---|---|---|---|---|---|
| T1 | S1 | inline | item 2 (signing guard) | done | `94c5db9` (RED 6 fail, GREEN 205/205; review approved) |
| T2 | S2, S3, S10, S5 (maxPrice) | inline | none | done | `5a209fc` (RED 4 fail, GREEN 210/210) |
| T3 | S9 + version 0.2.0 | inline | item 3 (public API) | done | `443933b` (RED 4 fail, GREEN 216/216; T2+T3 review approved) |
| T4 | S4 | inline | item 4 (cross-process lock) | done | `1f5c7ff` (RED race 3/5 runs, GREEN 221/221, race test 10/10) |
| T5 | S5 (transport, KeySession), S6 | inline | item 2 (sign-in error path) | done | `f0918cb` (RED 4 fail, GREEN 227/227) |
| T6 | S7 | inline | item 5 (CI) | done | `e8dca83` (RED Node 20 "Could not find .../*.test.js", GREEN 227/227 on Node 20 and 24) |
| T7 | S8 | inline | none (additive error code) | done | `f24636d` (RED 1 fail, GREEN 12/12; server suite 1690/1690 per directory) |

## Log

- **L1 (2026-11-25, user):** "Okey, empecemos entonces", on the agreed order "#394 first, then #424".
- **L2 (2026-11-25, user decision):** approve API = "Required, opt-out explicit (Recommended)".
- **L3:** an explorer mapped the 10 items on `cb69502`, and a parent spot check confirmed `guard.ts:390-395` and `sdk.ts:668`. Route: every task runs inline, because no writer trigger applies (the units run in sequence).
- **L4 (T1):** the fee bound is `Puls3Network.maxFeeBps`, set to 0 in TESTNET because production sets `PULS3_PLATFORM_FEE_BPS` to 0 (puls3_server/README.md, "First deploy"). `max_fee_bps` is the client's cap, and the escrow already refuses anything above 1000, so a cap of 1000 would protect nothing. `registrationOrigin` is the production web origin (docs/verification/live-hire.md:75). RDD review (risk, reliability): approved and acknowledged. Advisory findings: (a) a local `withNetwork` now needs `registrationOrigin` (pending follow-up: a refusal message that names the setting); (b) fee 0 rests on the production config, not on a live read; (c) "base with a path" does not apply, because the server uses `base.origin` (`deploy_chain.dart:85`).
- **L5 (T2, T3):** review (risk, readability, reliability) approved. The follow-ups were applied in `e72946a`: the retry rule of #waitHire, the messages, and direct tests.
- **L6 (T4):** RED came from 6 real programs racing on a stale lock. It failed in 3 of 5 runs, on Windows as `EPERM` from concurrent removal. GREEN passed 10 of 10. Review (resilience, reliability) approved; its follow-ups landed in `fa849a0` (release retry, EPERM/EACCES on takeover, rename-claim of a stale takeover, heartbeat on the directory), and that review was approved too. Open follow-ups, not fixed: (a) the put-back window of `removeStaleTakeover` (only reachable after a program died mid-takeover plus 3 concurrent programs); (b) a persistent EPERM on takeover surfaces as a lock-wait timeout without its cause; (c) no direct tests for the unreadable-owner branches.
- **L7 (T5):** RED was 4 failures (a non-JSON 200, a signer failing at sign-in, an unreadable sign-in answer, a hung RPC); GREEN 227/227. Review (risk, resilience) approved with no findings.
- **L8 (T6):** on Node 20 the glob fails with "Could not find ...\build-test\test\*.test.js". A directory argument does not fix it: Node 20 also runs the helpers, and Node 24 refuses it. `scripts/run-tests.mjs` lists the files instead. 227/227 on Node 20.19.5 and 24.18.0. The Node 22 leg runs only in CI, still pending until the branch is pushed. Review approved; its only finding was this Node 22 gap.
- **L9 (T7):** RED 1 failure, GREEN 12/12 in `studio_deploy_service_test.dart`. The server suite passes per directory: 1690/1690. The whole-package `dart test -x integration -x e2e` exits 1 after ~327 tests on baseline `cb69502` too, so it is environmental and pre-existing. The `AgentAlreadyRegistered` code is documented in `docs/architecture/api.md`.
- **L10:** an independent verifier runs at the end of the feature (high-risk items 2, 3, 4, 5).
- **L11 (verify):** the independent verifier passed S1-S10 at `f24636d`. S7's Node 22 leg is not verifiable locally and is left to CI. Its stress test (8 programs × 15 rounds, a stale lock and a stale takeover planted, one holder exiting mid-lock) found no overlap and left no stray lock. Its probes are added as regression tests. Of its advisories, (1) is fixed: a `trustServer` inherited from a polluted `Object.prototype` opted out of the check, and `reviewedResult` now reads own properties only (RED 1, GREEN 247/247 on Node 20 and 24). Left as follow-ups: (2) a hung RPC body is reported as "no JSON"; (3) a negative or NaN `timeoutMs` is not checked up front; (4) a `Puls3HttpError` during login and non-API refresh errors still end as a 401; (5) `lockWaitMs` 30 s < `staleLockMs` 60 s, which predates this change.
