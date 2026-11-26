# 438-sdk-ts-followups

Objective: close the open follow-ups of the #424 review and verifier in `puls3_sdk_ts` (#438).
Branch: `fix/438-sdk-ts-followups` from `main` at `e5b3dbf`. Delivery: ask-on-risk, one PR expected (forecast ~350 authored lines). Runner: `cd puls3_sdk_ts && npm run check && npm test` (Node 20, 22 in CI; Node 24 locally).

## Specs

Each spec is a deliverable of #438, which quotes `odd/tasks/424-npm-sdk-checks.md` L4, L6 and L11.

- **S1 (L4a).** "With `withNetwork` pointed at a local server, `register_full` is refused with "the agent URI is not on the registration origin https://puls3-hub-on-stellar.serverpod.space" (`guard.ts`). The message should say to set `registrationOrigin` in `withNetwork` to the server's web origin." Acceptance: the refusal names `registrationOrigin` and `withNetwork`; it is still `SigningRefused`.
- **S2 (L11-2).** "When the `AbortSignal.timeout` fires while `response.json()` reads the body, `chain_reader.ts` throws `Puls3ProtocolError(... with no JSON)` instead of the `Puls3NetworkError` a hung RPC gets." Acceptance: a body that hangs past `timeoutMs` ends as `Puls3NetworkError`; a body that is not JSON stays `Puls3ProtocolError`.
- **S3 (L11-3).** "A negative, zero, `NaN` or infinite `timeoutMs` reaches `AbortSignal.timeout` and fails on the first read, or never times out." Acceptance: `SorobanRpcReader` throws a `TypeError` naming `timeoutMs` at construction for each of those values; a positive finite value is accepted. Assumption: `timeoutMs` is a `SorobanRpcReader` option (`chain_reader.ts:60`), not a `withNetwork` one, so the check lives in the reader.
- **S4 (L11-4).** "A `Puls3HttpError` from `createChallenge`/`verifyChallenge` (for example a 502) is treated as a refused sign-in, and a refresh that fails for any reason other than the server refusing it returns `failedOther`. In both cases the call goes out without a session and the caller sees a 401 instead of the real error (`key_session.ts`)." Acceptance: both surface the original error to the caller; a server refusal (`Puls3ApiError`) keeps today's behavior.
- **S5 (L11-5).** "`lockWaitMs` is 30 s and `staleLockMs` is 60 s (`session.ts`), so a program waiting on the lock of a program that just died times out before it is allowed to take the lock over. The wait must outlast the stale threshold." Acceptance: the default wait is longer than the default stale threshold plus one heartbeat; a waiter on a lock whose owner died takes it over instead of timing out.
- **S6 (L6b).** "When Windows keeps refusing the takeover directory, `removeIfStale` returns quietly on every try, and the waiter ends with "Timed out waiting for the session lock" without the refusal." Acceptance: the timeout message includes the last refusal code.
- **S7 (L6a, rewritten after L5).** "When a fresh takeover was renamed by mistake, it is renamed back; between the two renames a third program can create a new takeover, and the put-back then fails and removes the fresh directory." Acceptance: the race neither takes the lock from anyone nor leaves a stray `<lock>.takeover.<hex>` directory. (The original acceptance, "never removes a takeover another program owns", rested on a wrong premise: see L5.)
- **S8 (L6c).** "No direct tests for the unreadable-owner branches of `ownerOf`, `removeIfStale` and the release in `acrossProcesses`." Acceptance: one direct test per branch.

## Tasks

- [x] T1 · S1 · inline · guard refusal names the setting · `293f49c` · RED 1 → GREEN 248/248
- [x] T2 · S2, S3 · inline · RPC body timeout and `timeoutMs` check · `1706c69` · RED 5 → GREEN 255/255
- [x] T3 · S4 · inline · sign-in and refresh errors reach the caller · `cc9d71e` · RED 2 → GREEN 259/259
- [x] T4 · S5-S8 · inline · session lock (Risk: item 4, concurrency; own commit) · `cebe379` · RED 4 (S5 ×2, S6, S7; S8's 3 direct tests pass as coverage) → GREEN 266/266, 5 runs stable · independent verifier: S1-S8 PASS, no blockers (L5)
- [x] T5 · S3, S6, S7, S8 · inline · verifier advisories A1-A3 and its probes as regression tests · RED 5 (A1 ×3, A2, A3) → GREEN 275/275, 3 runs stable
- [x] Docs · CHANGELOG `Unreleased` section · `b5e433e`; release 0.2.1 · `c82c53a`

## Log

- **L1 (2026-11-26, user):** "Dale, sigamos con los follow-ups de #424"
- **L2:** Issue #438 created from the open follow-ups of the #424 log (L4a, L6a-c, L11-2 to L11-5). Route: all tasks inline (no Writer trigger: one understood change each, under ~100 lines). T4 names Risk item 4 (concurrency), so it gets its own commit and an independent verifier.
- **L3 (S5 decision):** raise the default wait instead of lowering the stale threshold. A lower threshold could take the lock from a slow but live holder (a blocked event loop misses heartbeats), which revokes the session; a longer wait only costs time when a holder died.
- **L4 (2026-11-26, user):** "Si, debemos de sacar la siguiente version con los cambios". Version 0.2.1: a patch, since nothing is removed or renamed (`docs/sdk/releasing-npm.md`).
- **L5 (verify):** the independent verifier passed S1-S8 at `cebe379`, with no blockers: T4 cannot put two programs in the lock at once, cannot make a live holder lose its lock, and leaves no stray lock. Advisories:
  - A1: `timeoutMs` 1.5 or 2^32 passed construction, then every read failed with a raw `RangeError`. Fixed: a whole number from 1 to 2147483647.
  - A2: `?? refused` blamed one early refusal forever. Fixed: the last try decides.
  - A3: the put-back change left an orphan `<lock>.takeover.<hex>` that nothing cleans. The program that made the moved directory only uses the plain name, so removing it was already harmless. S7's premise was wrong: the put-back failure is reverted to `removeDir(claimed)`, and S7 is rewritten.
  - A6: added a test for the second read in `removeIfStale`.
  - The verifier's probes P-S2, P-S5a, P-S5b, P-S6a, P-S6b, P-S7a and P-S8 are now regression tests.
  - Known limits, not fixed, both predating this change: A4, on POSIX a put-back renamed onto a third program's empty takeover replaces it (Windows refuses with `EPERM`); a token file inside the takeover would make that rename fail. A5, if a program dies mid-takeover just as the lock goes stale, a waiter can still time out at 90 s (two deaths in a row).
