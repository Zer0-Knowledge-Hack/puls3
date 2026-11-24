# Feature: an agent subcontracts another agent from a consumer-funded budget (#334)

- **Branch:** `feat/334-agent-subcontracting` (from `origin/main` `64a6793`)
- **Locator:** `odd/tasks/agent-subcontracting.md` · Engram `odd/agent-subcontracting/tasks`
- **Delivery strategy:** `ask-on-risk`. Chain strategy: **`stacked-to-main`** (user, 2026-11-18,
  for traceability). Each PR targets `main` and lands in order. A later slice branches from the
  previous slice until that one merges, then rebases on `main`.
- **Slices (one PR each):**
  1. T1 ADR-0011 (`feat/334-agent-subcontracting`)
  2. T2 escrow contract
  3. T3 server domain and ledger bindings
  4. T4 marketplace search
  5. T5 runtime tool loop
  6. T6 subcontract executor
  7. T7 web
  8. T8 evidence

  If a slice cannot fit ~400 lines after one honest split, it goes with a `size:exception`
  rationale.

## Objective

A consumer hires agent A with a task. When part of the task is beyond A, A's model searches the
marketplace (skill, reputation, price), picks the best agent B and subcontracts it, without any
further consumer signature. B is paid **from a subcontract reserve the consumer funded at hire
time, held by the escrow**, never from A's wallet. A delivers the combined result. Unspent reserve
returns to the consumer, and the contract emits an itemized, on-chain receipt.

## Decisions (user, 2026-11-18)

- **Path 1, the budget-bearing escrow.** Change the escrow contract instead of having A front money
  from a float. Reason: one consumer signature, no float or credit risk for A, and a subcontract tree
  that can be checked on-chain. No public ERC-8183, AP2 or x402 design covers parent→child budget
  propagation (research 2026-11-18), so this is puls3's contribution.
- **Payment of a completed child is final** (Policy 1). If the consumer later rejects the parent, B
  keeps its pay, because B delivered. The consumer agrees to this at hire time.
- **Related-party subcontracts are allowed, not banned.** A builder's agent suite may hire its own
  agents. Instead of a ban:
  - the related-party link is disclosed in the receipt and the consumer's view;
  - the server ranks the candidates objectively, and the pick is justified against that ranking or a
    price no higher than an independent alternative;
  - the consumer can opt out at hire time (default: allowed, with notice);
  - A's rating of a related-party B does not count toward reputation.

  Cycles and depth beyond the limit are refused. Reason: an owner ban hurts honest builders and is
  trivially evaded with a second wallet.
- **Agent-signed calls are serialized per wallet by reading the signer from the stored envelope**
  (user, 2026-11-23, T6.4.2: "Vamos con la B, pero que quede explicito el porque decidimos esto").
  `chain_submission` does not record who signed a call. The options were (A) a new `source` column
  with a migration, or (B) decoding the source account of the signed envelope that is already
  stored. B was chosen for these reasons:
  - It changes no persisted format, so it needs no migration and no rule for existing rows without
    a value (option A is high-risk item 1).
  - Every agent-signed envelope already carries its source account.
  - The set it reads is small by design. It holds only the `submitted` rows of the four
    agent-signed purposes, because each wallet keeps at most one in flight, so decoding them each
    pass is cheap.

  The cost is a less explicit query and one decode per in-flight row on every pass. Revisit with a
  column if that set grows or the pass gets hot. An envelope that cannot be read fails closed: it
  holds every wallet, which is the old global gate. The reasoning is also in the doc comment of
  `agentCallInFlight` (`puls3_server/lib/src/chain/agent_call_gate.dart`).

## Constraints

- ADR-0005 D6: `HireStatus` mirrors the escrow job 1:1, so "waiting for a subcontract" is run data,
  not a hire state. The ADR must amend ADR-0005 D9 (consent for re-hiring) and D10 (no hooks), and
  ADR-0006 D6 (agent spend is the builder's).
- The escrow is audited (2026-10-25). Contract changes need tests, an audit note and a testnet
  redeploy. Today the escrow: has a fixed `budget`, has no top-up, rejects hooks, and caps
  `max_expiry` (#333).
- The runtime does one text-only model call today: no tools, no structured output, no
  pause/resume, 120 s timeout, sequential runner.
- Testnet only. Secrets never printed.

## Tasks

- [x] **T1** (done 2026-11-18: delegated writer; `docs/adr/0011-budget-bearing-escrow-and-agent-subcontracting.md`,
  D1–D11, status Proposed; structural readback by parent. Notable choices: new `fund_with_reserve`
  keeps the ERC-8183 signatures, the parent cannot `submit` while a child is open, depth 2, a new
  escrow deploy because the escrow has no upgrade entrypoint, and rating readers must accept the old
  escrow id) ADR-0011, budget-bearing escrow and agent-initiated subcontracting. The 0010 number is
  taken by PR #346. Contents: consumer reserve, `create_child_job` from the reserve, child lifecycle
  and refund to the reserve, parent close releasing unspent reserve, receipt events, depth limit and
  cycles, related-party rules, the runtime tool loop and run phases, and the amendments to ADR-0005
  D9/D10 and ADR-0006 D6. Route: delegated writer (ADR needs preparation reads of 0004/0005/0006).
- [x] **T2** (done 2026-11-18. Route: delegated writer, trigger 2+ non-trivial files plus preparation
  reads. RED: 86 compile errors. GREEN: `cargo test -p escrow` 179/179 (149 existing, 30 new);
  clippy, fmt and the WASM build (rustup 1.98.1, 37,168 B) are clean. Version bumped to 0.2.0.
  Commits `ac63a7b` (source and tests, ~1,430 authored lines) and `6365e02` (generated snapshots).
  Native review: risk high, granted. The first attempt with snapshots hit
  `lens_context_budget_exceeded`, so the commit was split. The re-run had 4 lenses, came back
  approved and was acknowledged (lineage `review-efe2486d9d0ef315`).
  Known local flake: Windows `Os 1224` while writing snapshots, which is environmental. CI on Linux
  is the authority.) Escrow contract: reserve at `fund`, `create_child_job`, child settle/reject/expire
  accounting against the parent reserve, parent completion refunding unspent reserve, events.
  Rust tests including the invariant (sum of children ≤ reserve, child expiry ≤ parent). Route:
  delegated writer.
- [x] **T3** Server domain and persistence: hire subcontract cap and related-party opt-out,
  `parentHireId`, receipt line items, migrations, ledger bindings for the new entrypoints. Route:
  delegated writer (trigger: 2+ non-trivial files across domain, server, ledger and migrations,
  mapped first by a read-only explorer). Done 2026-11-18, split by the user's choice into two
  stacked slices with the same final tree as the unsplit work (`backup/334-t3-unsplit`):
  - Slice A `feat/334-ledger-subcontract`: `2386ef4` ledger bindings (events, v0.2.0 job decoder,
    errors 124-127, `contractFunction`, `draftCreateChildJob`), +748/-20.
  - Slice B `feat/334-server-subcontract`: `ec44b71` domain, persistence and hire creation with a
    reserve (+673/-12), `7cbe47a` regenerated protocol and migration
    `20261118221650421-hire-subcontract`.
  Checks at A: server `dart analyze --fatal-infos` clean, `dart test test/unit test/hire` 1063
  passed, domain 301 passed. Checks at B: domain 309 passed, server analyze clean,
  `dart test test/unit test/hire` 1077 passed, `dart test test/integration` 185 passed, client
  analyze clean; a second `serverpod generate` changed no content. Native review of the unsplit
  source: medium risk, granted, one reliability lens, approved and acknowledged (lineage
  `review-f955cb3b83a47254`). Each split slice was reviewed again as its own target: A `2386ef4`
  (medium, granted, reliability lens, approved and acknowledged, lineage
  `review-bc7e85bf85502f8d`) and B source `ec44b71` on base `2386ef4` (medium, granted, reliability
  lens, approved and acknowledged, lineage `review-cb09b5b886640baf`). Notes:
  `fund_with_reserve` stays under purpose `fund` (the tracker only funds on `fund`), and the wire
  function name now comes from `SubmissionPurpose.contractFunction`. `createChildJob` is untracked
  by `chain_submission_tracker.dart` until T6. `allowRelatedParty` defaults to true (D10) and is
  stored only. The reserve ceiling comes from `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS`. The
  `fund_with_reserve` encoding lives in slice B because it reads `HireRow.subcontractReserve`.
- [x] **T4** Server-side marketplace search for agents: skill, rating, paid hires, price, `hireable`,
  related-party flag, excluding self and cycles, ranked objectively. Route: delegated writer.
  Evidence: domain `dart test` 338 passed, server unit+hire 1087 passed, integration 186 passed,
  `dart analyze --fatal-infos` clean on both packages. `buildAgentSearchService` is wired in
  `agent_catalog_wiring.dart` with no endpoint yet; T5's `search_agents` tool is its caller.
  Source `719e732` on base `3317962` (assessed high, consent medium, granted, reliability lens,
  approved and acknowledged, lineage `review-4bcab53db6eb5cf2`). Advisory, non-blocking follow-ups:
  ancestor wallets read from the catalog (`agent_search_service.dart:71-77`, warning), untested
  chain cap, non-ASCII query matching, and untested wiring.
- [x] **T5** Runtime tool loop (Workers AI and Anthropic tool calling, bounded turns) with
  `search_agents` and `subcontract` tools, plus run phases (run → waiting for a child → resume).
  Route: delegated writer, one work unit and one stacked PR each (user approved 2026-11-18).
  Defaults: 8 turns max per hire; `max_children` with a platform cap of 2, both config with
  defaults; a mid-loop provider failure resumes from the stored transcript; Studio runs use the
  loop too; the transcript is stored in Postgres within the existing limits; if Workers AI tool
  calling on llama-3.3-70b is unreliable, subcontracting is Anthropic-only. T5 ends at a persisted
  `awaitingChild` and a resume proven with a fake `SubcontractPort`; T6 wires the real child.
  - [x] **T5.0** Manifest opt-in `subcontract { max_children, suggested_reserve }` on domain
    `AgentManifest` and server `RunManifest`; manifests without it keep their hash.
    Evidence: RED (compile failures) then GREEN; domain 349 passed, server unit+hire 1092 passed,
    analyze clean on domain and server, `flutter analyze` clean on `studio_form_check.dart`.
    New `ManifestProblem.subcontractMalformed` and `subcontractInvalid`. Canonical JSON of the
    workers-ai example is pinned byte for byte. Cap is the constant `subcontractMaxChildrenCap = 2`
    (no env var); `effectiveMaxChildren` is 0 without the opt-in. Studio form is T7.
    Source `0c0c346` on base `e5b151e` (assessed high, consent medium, granted, reliability lens,
    approved and acknowledged, lineage `review-11982293292aec6a`); two advisory suggestions in
    `run_manifest_test.dart:144-163` and `studio_form_check.dart:312-315`.
  - [x] **T5.1** Tool calling in the model adapters: `ToolSpec`, conversation messages, `ModelTurn`
    (final text or tool calls), `converse()` beside `complete()` for Anthropic and Workers AI.
    Evidence: RED (5 new test files failed to load) then GREEN; runtime 161 passed, server
    unit+hire 1124 passed, analyze clean. `ConversationRuntime implements ModelRuntime` keeps
    other implementers compiling. Workers AI: Cloudflare documents `tool_calls` without a call id
    and no way to return tool results
    (developers.cloudflare.com/workers-ai/models/llama-3.3-70b-instruct-fp8-fast/), so
    `WorkersAiRuntime.converse` throws `tools_unsupported` with tools; subcontracting is
    Anthropic-only. Anthropic assistant `content` is kept as opaque `providerContent` and replayed
    verbatim; T5.3 must persist it in the transcript.
    Source `30663b6` on base `70bc765` (consent medium, granted, reliability lens, approved and
    acknowledged, lineage `review-0479630263c40896`); one advisory suggestion in
    `agent_runner.dart:72-84`.
  - [x] **T5.2** Bounded tool loop with `search_agents` (T4) and `subcontract` behind a
    `SubcontractPort`.
    Evidence: RED (both new test files failed to load) then GREEN; the two new files pass 29
    tests, server unit+hire 1153 passed, analyze clean. `ToolLoop.start` / `resume` return a sealed
    `LoopOutcome` (`LoopCompleted`, `LoopAwaitingChild`, `LoopFailed`) carrying an immutable
    `ToolLoopState`. `defaultMaxLoopTurns = 8`, counted across resumes; the deadline is checked
    before each segment. Tools are offered only with `effectiveMaxChildren > 0` on Anthropic;
    otherwise a single `AgentRunner.run`. Untrusted text goes in `<untrusted_data>` with `<` and `>`
    escaped as JSON unicode escapes. Price comes from the search snapshot, never the model.
    T5.3 must persist the full `ToolLoopState`, the pending call id, the child hire id and the
    `ChildRequest`, and needs a tool-capable runner for Studio (`OwnedRunManifest`) runs.
    Source `4170668` (consent medium, granted, reliability lens, approved and acknowledged,
    lineage `review-525194518622257e`) raised two warnings, fixed in `d80a465`: `subcontract` is
    refused with `no_turns_left` or `no_time_left` before the port is called when no follow-up
    segment is possible, so no child is paid without being consumed; and an in-turn duplicate call
    id runs no call and gets exactly one `duplicate_call_id` result. Fix reviewed (consent medium,
    granted, reliability lens, approved and acknowledged, lineage `review-dafe0e08a5ee9316`);
    server unit+hire 1158 passed, runtime 195 passed.
  - [x] **T5.3** Run phases `running` → `awaitingChild` → `running`: transcript, child hire id and
    turns persisted (migration), and `HireRunner` resumes paused runs.
    Evidence: RED (three new test files failed to load) then GREEN; server unit+hire 1183
    passed, runtime 219, integration 193, analyze clean on server and client, a second
    `serverpod generate` changed nothing. Source `171ae66`, generated + migration
    `20261119030418895-hire-run-phases` in `d4e9ef8` (four nullable `hire_run` columns).
    `awaitingChild` maps to runtime status `running`, so the hire stays `funded` (D7). The
    `tool_loop_codec` is version 1; an unreadable state fails as `loop_state_unreadable`. A
    retryable mid-loop failure continues from the stored state via `ToolLoop.continueFrom`.
    Studio runs reach the loop through `runnerLease` / `withBuilderRunner`. Production wires
    `subcontracting: null`, so no tools are offered until T6. T6 must implement `SubcontractPort`,
    `ChildResultSource`, wire `SubcontractSetup`, raise `staleAfter` and `TrackerLoop.passTimeout`
    for multi-segment runs, and reconcile half-opened children after `internal_error`.
    Review of `171ae66` (consent medium, granted, reliability lens, approved and acknowledged,
    lineage `review-cc09f7096e96ab6f`) raised two warnings, fixed in `67ed0ee`: `markResumed`
    now stores the loop state with the child's tool result in the same conditional write, so a
    lease failure before the first segment cannot lose a paid child's result; and
    `listAwaitingChild` returns damaged rows as `DamagedAwaitingRun`, which the runner fails as
    `loop_state_unreadable` or `not_runnable`, so they cannot starve the batch. Fix reviewed
    (lineage `review-96d9662ed6bd2465`, approved and acknowledged); its warning that
    `_failDamaged` skips hire settlement does not hold, because `_fail` does not settle either
    (`hire_runner.dart:552-570`); releasing an already-opened child stays a T6 item. Server
    unit+hire 1191 passed, runtime 227, integration 194.
- [ ] **T6** Subcontract executor: runtime → child job from the reserve, A evaluates B, A's run
  resumes with B's result, receipt stored. Route: delegated writer, one work unit and one
  stacked PR each (user approved 2026-11-19; the chain is now 15 slices).
  Defaults: the verdict is a server rule (D3): reject when B's run failed, its output is empty or
  over the output limit, otherwise complete; the reason hash is sha256 of the reason code. An
  undecided child is released by the existing deadline relay. Child `expired_at =
  min(now + job duration, parent.expired_at − approval_window − 600)`; `subcontract` refuses with
  `parent_too_short` before opening a child that could not submit in time. The child reserve is 0
  (depth 1, D5). The example job duration becomes 259200 s: with the testnet 24 h
  `approval_window`, a parent needs two windows plus the 600 s margin, so 172800 leaves no room for
  a child (`set_approval_window` can shorten the window later; that is a deploy choice for T8).
  - [x] **T6.1** Real `SubcontractPort`: child hire + receipt line, A-signed `create_child_job`,
    contract refusals as tool errors, idempotent per tool call.
    Evidence: RED (port test failed to load) then GREEN; server unit+hire 1217 passed,
    integration 199 (receipt store on Postgres), analyze clean. Source `16c1297`.
    `EscrowSubcontractPort` checks the chain job, drafts and signs with A before any write, then
    one transaction stores the child hire (`requestId = child:<parentHireId>:<toolCallId>`), the
    receipt line and the submitted `createChildJob` record; the envelope is sent after it. The
    approval window is read live from the contract (`contractApprovalWindow`).
    `childRunHeadroom = 30 min`; `parent_too_short` when `childExpiry <= now + window + headroom`.
    A node refusal marks the line `not_opened`; an unreachable node leaves it `pending`.
    Open items: T6.2 confirms the job and moves the line from `pending`; T6.4 builds
    `ChildAgentLookup`, wires `contractApprovalWindow`, and must serialize A's account sequence
    with other submits (`txBadSeq` today ends as `chain_refused`). `tool_loop_codec` does not
    store `ChildRequest.toolCallId`, which only matters if a restored request is re-sent.
    Review of `16c1297` (consent medium, granted, reliability lens, approved and acknowledged,
    lineage `review-d42625275e3c0841`) raised three warnings. Two are fixed in `f3f7df6`: the
    stored-child lookup now runs first and reads only the database (`listByParent` plus the
    child's `requestId`), so a retry after a chain failure or a parent state change returns the
    stored child instead of risking a duplicate; and an integration test against the Serverpod
    stores proves the child hire, receipt line and submission roll back together (it fails when
    `insertHire` leaves the transaction). The reserve race does not hold: a hire has one run
    (`hire_run` unique on `hireId`, conditional writes), the loop refuses a second `subcontract`
    in a turn, and the contract checks the reserve. Fix reviewed (lineage
    `review-bfbfb6031598701e`, approved and acknowledged); its warning that a child hire without
    a receipt line rethrows a raw `HireRequestConflict` is a T6.4 item (map it to
    `SubcontractRefused`). Server unit+hire 1221 passed, integration 201.
  - [x] **T6.2** Track `createChildJob`: bind the child job, record the payment (payer A, payee B)
    so B's run is enqueued, update the receipt line.
    Evidence: RED (new tests failed to load) then GREEN; server unit+hire 1254 passed,
    integration 208, analyze clean. Source `2b9b32e`. The tracker's new `createChildJob` case
    reads `ChildJobCreated` (plus `JobCreated` / `JobFunded`) and calls `onChildJobCreated`,
    which validates every field against the stored child and, in one transaction, binds the
    job, records the payment (which enqueues B's run) and moves the line to `funded`. A proven
    failure moves the line to `not_opened`; a mismatch or missing evidence moves it to
    `unverified` and funds nothing. Reprocessing is idempotent (`alreadyOpened`).
    `createChildJob` stays out of `_relayPurposes` (one envelope per child). Review (consent
    medium, granted, reliability lens, approved and acknowledged, lineage
    `review-bd9662d5cc0abd5d`); its warning that a job id taken by another hire could fund a
    child does not hold, because `hire.jobId` and `hire_payment.transactionHash` / `jobId` are
    unique (`hire.spy.yaml:35-36`, `hire_payment.spy.yaml:16-20`); only its Postgres test is
    missing. T6.4 must pass `children: ChildJobEffects` in `chain_tracker_wiring.dart` and
    reconcile `unverified` lines; T6.3 maps `not_opened` to `ChildFailed('child_not_opened')`.
  - [x] **T6.3** `ChildResultSource` and verdict: A-signed child `complete` / `reject`, receipt
    settlement fields, and no parent `submit` while children are open.
    Evidence: RED (new test files failed to load) then GREEN; server unit+hire 1300 passed,
    integration 210, analyze clean. Source `30f6e61`. `judgeChildOutput` returns
    `child_run_failed`, `child_output_empty`, `child_output_too_long` (over 16000 runes),
    `child_not_submitted` or `child_complete`; the reason hash is sha256 of the code.
    `EscrowChildResultSource` signs one verdict at a time with A's key under the new server-signed
    purposes `childComplete` / `childReject` (persisted by name); the tracker's `onChildSettled`
    fills the line's state, fee, payout and settle transaction. `AgentSubmitSender` takes an
    optional `childrenOpen` check (`OpenChildren.anyOpen`), and a `ChildrenOpen` refusal burns no
    attempt. Review (consent medium, granted, reliability lens, approved and acknowledged,
    lineage `review-6f18abf3c28cddc2`) raised two warnings, both moved to T6.4.
    PR #368 review (2026-11-23): `child_output_too_long` is removed. It could never fire, because
    no manifest may set `output.max_chars` above 16000 (`manifest.dart:418-425`), the Studio
    source revalidates on every run, and `AgentRunner` fails both `run` and `converse` over the
    limit (`agent_runner.dart:38,63`). `judgeChildOutput` no longer takes a limit; a
    16000-rune output is completed. RED: `child_verdict_test` failed to load; GREEN: server
    unit+hire 1300 passed, analyze clean.
  - [ ] **T6.4** Production wiring of `SubcontractSetup`, `staleAfter` and `passTimeout` for
    multi-segment runs, and reconciliation of half-opened children and children of failed runs.
    Carried items:
    - Wire `SubcontractSetup`, `ChildAgentLookup`, `contractApprovalWindow`, `ChildJobEffects`
      (in `chain_tracker_wiring.dart`), `EscrowChildResultSource` and `childrenOpen`.
    - Serialize agent-signed calls per signing wallet instead of globally: `AgentSubmitSender`
      already gated `submit` globally, and T6.3 widened that gate to the child purposes, so one
      stuck child call stalls every agent's submit (`agent_submit_sender.dart:132`).
    - Record relay settlements (`release`, `claim_refund`) on the child's receipt line; today
      only A-signed verdicts fill it (`child_job_effects.dart:160-186`).
    - Reconcile `unverified` and half-opened lines, release children of failed parent runs, map
      an orphan `HireRequestConflict` to `SubcontractRefused`, and handle a throwing
      `childrenOpen`.
    - Bound what child results add to A's conversation (found 2026-11-23). The whole transcript
      counts against `inputMaxChars + defaultConversationHeadroomChars` (32000,
      `tool_loop.dart:15,298`). Two children at the 16000-rune ceiling, plus search results and
      JSON escaping, exceed it, so A's next segment fails `input_too_long` after B was paid.
    - Bound the retries of a persistent `LedgerException` while preparing a verdict
      (`escrow_child_result_source.dart`, #368 review, non-blocking).

    Units (planned 2026-11-23, one commit each on `feat/334-subcontract-wiring`). The wiring
    comes last, because it turns the feature on in production:
    - [x] **T6.4.1** Bound child results in A's conversation. Route: inline (about 100 lines).
      `ToolLoop.resumedState` now takes `maxConversationChars` and cuts a delivered output to
      the longest whole-rune prefix that keeps the transcript within it, labelled with
      `truncated` and `output_runes`. RED: the new `child_result_budget_test` failed to compile.
      GREEN: server unit+hire 1304 passed, analyze clean. Risk: none.
    - [x] **T6.4.2** Serialize agent-signed calls per signing wallet. Risk: item 4 (concurrency),
      which needs an independent verifier. Route: inline (one understood change). Decision B above.
      `agentCallInFlight` reads `ChainSubmissionStore.submittedEnvelopes(agentSignedPurposes)` and
      `EnvelopeCodec.sourceOf`. `AgentSubmitSender`, `EscrowChildResultSource` and, which is new,
      `EscrowSubcontractPort` ask it with their own signer. Until now the port had no gate at all,
      so a `create_child_job` could reuse a sequence that A's `submit` or verdict was still
      holding. It now refuses with `chain_busy` before it drafts. Behavior change: if A
      subcontracts twice before the first `create_child_job` confirms, the second call gets
      `chain_busy`, where before it was likely a `txBadSeq` and `child_not_opened`. RED: the new
      tests failed to compile (`sourceOf` and `submittedEnvelopes` were undefined). GREEN: focused
      142 passed, then server unit+hire+ledger 1386 passed, analyze clean, and integration 211
      passed. The integration suite passed in 3 of 4 runs. The red run failed in two
      `chain_submission_store_test` `setUpAll` hooks, during database startup, not in the gate; the
      baseline also passed. Independent verifier: no blockers. Its probes were added as
      regressions:
      - `sourceOf` returns null for a muxed `M` source;
      - `agent_call_gate_test` runs the gate over the real codec and the recorded testnet
        envelope;
      - the verdict and the port fail closed on an unreadable envelope.

      Two integration tests that commit now confirm the call of A they leave in flight.
      Verifier notes, not fixed here:
      - (A, already true) Custodied-key `create_job`, `fund` and `complete` (`agent_hire_service`)
        are not in `agentSignedPurposes`, so they can share a sequence with that wallet's
        `submit`. User decision 2026-11-23: a separate follow-up, not part of T6.4.4. It touches
        the #312 A2A flow (Risk item 3) and gets its own test and commit.
      - (B, already true) The gate is check-then-act, not a lock.
      - (C) The `chain_busy` message gives the model no hint to wait and retry.
    - [x] **T6.4.3** Record relay `release` / `claim_refund` on the child's receipt line.
      Route: inline. A new `EscrowEffects.onRelaySettled` runs on a successful relay call before
      it is confirmed:
      - `release` records the line `completed`, with the `JobCompleted` fee and payout;
      - `claim_refund` records it `expired` with 0 and 0, because the budget went back to the
        reserve;
      - a line a verdict already settled is not changed;
      - a plain hire has no line, so nothing is written.

      Without `ChildJobEffects`, which is production until T6.4.5, the effect does nothing
      instead of throwing, so plain releases still confirm. An exception now leaves a relay call
      `submitted` for a retry, as it already does for the verdicts. RED: the tests failed to
      compile (`onRelaySettled` was undefined). GREEN: focused 123 passed, server
      unit+hire+ledger 1398 passed, integration 211 passed, analyze clean. Risk: none. The
      tracker's relay path also serves plain hires: pinned by the no-children test and the
      tracker tests.
    - [x] **T6.4.4** Reconciliation: `unverified` and half-opened lines, children of failed
      parent runs, orphan `HireRequestConflict`, a throwing `childrenOpen`, and bounded
      `LedgerException` retries. Mapped by a read-only explorer, then split into five
      independent fronts, each with a small inline route:
      - [x] **C** Orphan `HireRequestConflict`: when `_storedChild` finds no child of this
        parent, `requestChild` now refuses with `request_conflict` instead of rethrowing.
        Before, the error escaped `SubcontractTools`, and `_drive` failed the whole parent run
        with `runInternalError`. Everything had rolled back, so nothing is held. RED: the new
        port test failed with the raw `HireRequestConflict`.
      - [x] **D** A throwing `childrenOpen`: `AgentSubmitSender` now fails closed. The error is
        logged and the hire counts as having an open child. Before, it escaped `send` and
        aborted the rest of the pass. Production does not pass `childrenOpen` until T6.4.5.
        RED: the new sender test failed with `Bad state: database down`.
        C and D checks: analyze clean, unit+hire+ledger 1400 passed, integration 211 passed.
        Risk: none.
      - [x] **E** `LedgerException` retries in verdict preparation
        (`escrow_child_result_source.dart:250`): a plain `LedgerException` stores nothing,
        so it never reaches `maxEscrowCallAttempts`. User decision 2026-11-23 ("Vamos con la
        1"): keep it unbounded on purpose, as `AgentSubmitSender` does.
        - A node that cannot be reached is transient. Counting it would let a short RPC
          outage use up the attempts and leave the child without a verdict for good.
        - No other path frees the budget faster while the node is down, and the deadline
          relay still settles the child.
        - The cost is one warning per pass.

        The reason is written in the code, and a characterization test pins it: no attempt
        is used, and the verdict is sent once the node is back. There is no RED because the
        behavior did not change. Focused 21 passed, analyze clean. Risk: none.
      - [x] **B** Children of failed parent runs: `markFailed` dropped the run from
        `listAwaitingChild`, so A never judged its open children. The deadline relay then
        settled them, and its `release` paid a blank output without judging it.
        User decision 2026-11-23 (option 1): "Pues la 1, ya que es lo corecto, las reservas
        deben de quedarse trabadas hasta que el agent termine su trabajo, independientemente
        de quien lo haya contratado, si un humano u otro agente".

        The fix adds `HireReceiptStore.listUnsettled` (contract-tested on both stores) and
        `ChildResultSource.judgeOrphans`. `judgeOrphans` calls the same `resultOf` for each
        opened, unsettled line whose parent run is `failed`, and `HireRunner.pass` runs it on
        every pass. The sweep is isolated: one failing line, or a failing sweep, does not hold
        the rest. There is no migration and no schema change.

        RED:
        - the contract and the `judgeOrphans` tests failed to compile;
        - the runner tests failed with `Expected: <1> Actual: <0>`.

        GREEN: analyze clean, unit+hire+ledger 1408 passed, integration 212 passed. The
        server README is updated. Risk: none. It reuses `resultOf` and the per-wallet gate
        unchanged, and only children of failed parents are affected.
      - [x] **A** `unverified` and half-opened lines: they stayed stuck until the parent's
        deadline, and the relay never reached them because no `jobId` was bound. User decision
        2026-11-23 ("Dale, me gusta"):
        - scan the escrow from the parent's job id + 1 up to the first missing id, for a job
          whose fields match the child's;
        - one match: `ChildJobStore.open`, through the normal path;
        - no match: `not_opened`, but only after every envelope's `validUntil` has passed and
          no create was confirmed;
        - several matches, or a job another hire holds: the line stays unverified.

        The fix is a new `UnverifiedChildReconciler`, plus `HireReceiptStore.listUnopened` and
        `reopenUnverified`, contract-tested on both stores. Every write is a pending-only
        conditional one. It is not wired in production until T6.4.5.

        The reconciler tests passed on first run, because the code was written first. Two
        mutations each made them fail: dropping the `validUntil` guard, and dropping the
        re-mark on `taken`. The contract tests were written before the store code, but RED was
        not run on its own. GREEN: analyze clean, unit+hire+ledger 1420 passed, integration
        214 passed. Risk: item 4 (concurrency): the reconciler and the tracker can act on the
        same line, and the pending-only conditional writes resolve it.
        Independent verifier: no blockers, and every front was met. Its notes were fixed in one
        correction batch, with its probes added as regression tests:
        - a `JobMismatch` or `JobEvidenceUnavailable` create counts as landed, so it is never
          closed as `not_opened`;
        - a job an opened sibling holds is not a candidate;
        - an alike sibling that is also unopened makes the match ambiguous, because the jobs
          are interchangeable on chain and binding one could run the wrong task;
        - `landingMargin` (5 min) after `validUntil` covers clock skew and node lag.

        RED: 4 probes failed on the old code. The fifth, two reconcilers at once, already
        passed and now pins the behavior. GREEN: unit+hire+ledger 1425 passed, integration 214
        passed, analyze clean.
    - [x] **T6.4.5** Production wiring, plus `staleAfter` / `passTimeout` for multi-segment runs.
      Risk: item 5 (environment). Route: inline (resumed after an interrupted agent).
      `startAgentRuntime` builds `SubcontractServices` per pass (`buildSubcontractServices`:
      `EscrowSubcontractPort`, `EscrowChildResultSource`, `UnverifiedChildReconciler`,
      `OpenChildren.anyOpen`), with `childAgentLookup` (the `createHire` checks) and
      `contractApprovalWindow`; the reconciler runs once per pass and `childrenOpen` goes to
      `AgentSubmitSender`. `startChainTracker` passes `ChildJobEffects`. Fail closed: it is on only
      where `submit` is on and `PULS3_HIRE_JOB_DURATION_SECONDS` is set; no new switch (reserve
      needs `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS`, tools need a manifest opt-in).
      `runtimeTimings`: `staleAfter = timeout * 8 + 1 min`, `passTimeout = 2 * batch * 8 * timeout
      + 1 min` (derived from D8's 8 turns and the batch; not given as numbers by the ADR).
      RED: `child_agent_lookup_test` and `subcontract_wiring_test` failed to compile before the
      code. GREEN: unit+hire+ledger 1473 passed, `dart analyze --fatal-infos` clean. Integration
      not run: Docker needs `puls3_server/.env`, which this agent may not read. Commit: see git log.
      Risk: item 5.
- [x] **T7** Web: hire with a subcontract cap and a related-party toggle, and a receipt/subcontract
  tree on hire detail. Route: delegated writer. Branch `feat/334-web-subcontract` from `main`
  `6708683`. Mapped 2026-11-24 by a read-only explorer: `createHire` already takes
  `subcontractReserve` and `allowRelatedParty`; no endpoint exposes the reserve ceiling, the
  manifest opt-in, or the receipt lines (`HireReceiptLineRecord` is `serverOnly`); the Studio form
  drops `subcontract` on edit (`studio_form_check.dart:157-180`).
  - [x] **T7.1** (done 2026-11-24, `c3c65cb`; delegated writer, parallel with T7.2. RED: 28
    compile errors in the new tests. GREEN: server unit+hire+ledger 1523, `test/studio` 56,
    analyze clean on server and client, a second `serverpod generate` changed nothing;
    integration not run. New `HireRelayConfig.subcontractReserveMaxOrZero`, `explorer_links.dart`
    (the server had no explorer helper), `StudioRunManifestSource.onVersions`.) Server read API. A new `HireEndpoint.getHireTerms(agentId)` (reserve ceiling from
    `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS`, 0 when unset, plus the agent's `max_children` and
    `suggested_reserve` from its manifest, 0 without the opt-in), and `HireDetail.receipt`: the
    parent's receipt lines (`listByParent`) as a public `HireReceiptLine`, readable only by the
    parent hire's consumer, also on `StudioEndpoint.getAgentHire`. Regenerated client, `api.md`.
    Route: delegated writer, parallel with T7.2 (trigger: two independent units, disjoint
    surfaces, each several files and 200+ lines). Risk: none expected (adds an endpoint and
    optional fields).
  - [x] **T7.2** (done 2026-11-24, `f4611e3`; delegated writer. RED: unit tests failed to load,
    4 widget tests failed. GREEN: `flutter test` 545, analyze clean. The cap 2 is mirrored as
    `studioSubcontractMaxChildren`; the Studio refuses more than 2, the server would clamp. The
    switch is disabled for the free model, which cannot call tools.) Studio form opt-in: `max_children` and `suggested_reserve` in Advanced, mapped
    both ways so an edit keeps the opt-in, and `subcontractMalformed`/`subcontractInvalid` shown
    on the new field. Route: delegated writer, parallel with T7.1. Risk: none expected.
  - [x] **T7.3** (done 2026-11-24, `fb261d3`; delegated writer. RED: four test files failed to
    load. GREEN: `flutter test` 566, analyze clean. Choices: with reserve 0 the flag is sent as
    true; a resumed hire does not ask the consent again; terms that fail to load hide the section.)
    Hire form: a subcontract section only when the agent opted in and the ceiling is
    above 0, prefilled with `suggested_reserve`, capped by the ceiling, a related-party switch
    (default allowed, with notice), the "a completed subcontract is paid even if you reject the
    result" consent, and price plus reserve in the total and the funds check. The reserve and the
    flag are stored with the pending hire so a resume reuses them. Depends on T7.1.
  - [x] **T7.4** (done 2026-11-24, `edd0b40` consumer detail and `e30615e` agent-hire detail;
    delegated writer, surface extended once for `studio/` by the parent. RED: new tests failed to
    compile. GREEN: `flutter test` 584, analyze clean. One shared `hireReceiptEntries` mapping.)
    Hire detail receipt tree: one row per line with provider, related-party badge,
    budget, fee, payout, state, justification and explorer links, on the consumer's and the
    agent-hire detail. Depends on T7.1.
- [ ] **T8** Testnet evidence from the web: a consumer hires A, A subcontracts B from the reserve, A
  delivers, the unspent reserve is refunded, and every hash is checked. Record it in
  `docs/verification/334-agent-subcontracting.md`.

## Acceptance

Issue #334 acceptance, restated for path 1. On testnet, a consumer hires A with one signature that
funds A's price plus a subcontract cap. A's model subcontracts B through the reserve with no further
signature. B delivers, A delivers the combined result, and the consumer approves. The unspent reserve
returns to the consumer. The itemized receipt can be checked on-chain, and every tx hash on
StellarExpert.

## Checks

- Contracts: `cargo test` for the escrow, plus the existing cargo-audit workflow.
- Server: `dart analyze`, plus unit and integration tests for the changed services.
- Flutter: `flutter analyze` and `flutter test` for the changed screens.
- T8: RPC `getTransaction` SUCCESS for every hash, and Horizon balances.

## Progress

- 2026-11-18: research done (code map, agentic-payments landscape) and decisions recorded. Next: T1.
- 2026-11-18: T1 (PR #357), T2 (PR #358) and T3 (slice A PR #359, slice B PR #360) done; both T3
  slices reviewed and acknowledged.
- 2026-11-18: T4 done on `feat/334-agent-search`, stacked on `feat/334-server-subcontract`.
  T4 reviewed and acknowledged. Next: open the T4 PR stacked on #360 (user's call), then T5.
- 2026-11-23: answering the reviews before T6.4. ADR-0011 fixes for #357 and #361 in `d2a15a0` on
  `feat/334-agent-subcontracting` (Context says Option C changes #334's flow, the unspecified
  defaults and the D9/D10 scoring values are marked proposed, the child's treasury snapshot is
  documented). The `audit` failure on #357 is repo-wide: `main` fails too (new `heapless`
  advisories RUSTSEC-2026-0574 to 0582). #368: `child_output_too_long` removed (see T6.3).
  Next: push both, reply to the reviews, rebase #360/#363/#365/#367 (squash merges left them
  conflicting), then T6.4.
- 2026-11-23: both pushed; replies posted on #357, #361 and #368, and #334 links the ADR. The
  stack from `feat/334-server-subcontract` to `feat/334-child-verdict` was rebased with
  `--onto` past the squash-merged slices and force-pushed with lease. Each rebased tree differs
  from its `backup/334-pre-rebase-*` branch only by the ADR-0011 change, and #360 to #368 are
  mergeable with their approvals kept. Next: T6.4 on `feat/334-subcontract-wiring`.
- 2026-11-23: resumed after a power cut (tree clean at `da49afb`). T6.4.2 done with decision B
  (signer read from the stored envelope, no migration). Native review of `c30c7d7` (lenses resilience
  and reliability, lineage `review-453dd25ab4c54ba9`) granted, approved and acknowledged; the
  reviewed boundary is now `c30c7d7`. T6.4.3 done. Next: T6.4.4.
- 2026-11-23: user on verifier note A: "Follow up". It stays out of T6.4.4 as a separate
  follow-up. Next: T6.4.4.
- 2026-11-23: T6.4.4 C and D done (`7318113`). E decided by the user ("Vamos con la 1"): unbounded transient retries, documented and pinned. Next: B.
- 2026-11-23: T6.4.4 E done (`7376160`). B decided by the user (option 1: judge orphans by the normal rule) and done. Next: A.
- 2026-11-23: T6.4.4 B done (`92ecd7b`). A decided by the user ("Dale, me gusta") and done; T6.4.4 complete. Next: independent verifier for A (Risk item 4), then T6.4.5.
- 2026-11-23: verifier on T6.4.4: no blockers; its 4 notes on A fixed in one batch with regression tests. Next: native review of the slice (user consent), then T6.4.5.
- 2026-11-23: native review of `c30c7d7..a1aad7c` (lenses risk, resilience and reliability; lineage
  `review-f220e18d6da284a4`; escalated as Risk item 4) was granted, approved and acknowledged. The
  reviewed boundary is now `a1aad7c`. The six advisory findings do not block and are follow-ups:
  - R3-alike-siblings-wait: alike unopened siblings wait until the parent's deadline
    (`unverified_child_reconciler.dart:133`);
  - R3-orphan-sweep-isolation-untested: the per-line try/catch in `judgeOrphans` has no test;
  - R3-plain-relay-depends-on-effect (`chain_submission_tracker.dart:386`);
  - R3-reopen-before-open: `reopenUnverified` runs before `open`. A crash in between leaves the
    line `pending`, and a later pass recovers it;
  - R4-orphan-log-drops-cause: the orphan log prints only the error type;
  - R4-reconciler-unbounded-rescan: each pass rescans from the parent's job id.

  Next: T6.4.5 production wiring. It should also wire `UnverifiedChildReconciler.reconcile` into
  the runtime pass.
- 2026-11-24: T6.4.5 shipped as #407 (moises-cisneros, `59a1ba2`). TOMOKI977's review asked for
  one-call timings with subcontracting off (a hung pass could hold the queue for over 5 h) and
  tests for the fail-closed gate and the tracker's child effects. moises fixed both in `c125bba`
  (`subcontractEnabled`/`subcontractOffReason`, `agentRuntimeTimings`, `hireEscrowEffects`, a
  startup count of runs left `awaitingChild`, search on the injected `env`). A parallel local fix
  of the same review was dropped in favour of it (kept as `backup/407-our-fix`). README updated to
  the new timings. Next: T7.
- 2026-11-24: user: "Si, ahora si, podemos arrancar" (T7). T7 split into T7.1-T7.4 after a
  read-only map. Choices made without a product question: the hire form shows the subcontract
  section only for agents that opted in and only where the ceiling is above 0; the ceiling and the
  opt-in come from a new pre-hire read (`getHireTerms`) instead of new `AgentSummary` fields, so
  the catalog does not read manifests. T7.1 and T7.2 start in parallel.
- 2026-11-24: T7 done on `feat/334-web-subcontract` (T7.1 `c3c65cb`, T7.2 `f4611e3`, T7.3
  `fb261d3`, T7.4 `edd0b40` and `e30615e`). Not pushed. Next: PR slicing (stacked-to-main), then T8.
- 2026-11-24: user: "Si, hagamoslo asi". T7 pushed as four stacked PRs (slice 15 split): #411
  15a T7.2 Studio opt-in (`feat/334-t7-studio-optin`, base `main`), #412 15b T7.1 server read API
  (`feat/334-t7-hire-terms`), #413 15c T7.3 hire sheet (`feat/334-t7-hire-sheet`), #414 15d T7.4
  receipt (`feat/334-t7-receipt`). Order is T7.2 first because T7.2 and T7.3 append to the same ARB
  files. Each slice is above 400 lines (tests are about half) and asks for `size:exception`. CI
  runs only on #411 until each base merges. Next: reviews, then T8.
